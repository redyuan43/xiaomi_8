#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static volatile sig_atomic_t running = 1;

static void handle_signal(int signal_number)
{
    (void)signal_number;
    running = 0;
}

static int parse_dimension(const char *name, const char *value)
{
    char *end = NULL;
    long parsed;

    errno = 0;
    parsed = strtol(value, &end, 10);
    if (errno || !end || *end != '\0' || parsed < 0 || parsed > 16384) {
        fprintf(stderr, "invalid %s: %s\n", name, value);
        exit(EXIT_FAILURE);
    }

    return (int)parsed;
}

static int read_option(int argc, char **argv, const char *name, int required)
{
    int index;

    for (index = 1; index < argc; index++) {
        if (strcmp(argv[index], name) != 0)
            continue;
        if (index + 1 >= argc) {
            fprintf(stderr, "missing value for %s\n", name);
            exit(EXIT_FAILURE);
        }
        return parse_dimension(name, argv[index + 1]);
    }

    if (required) {
        fprintf(stderr, "missing required option %s\n", name);
        exit(EXIT_FAILURE);
    }

    return 0;
}

static Atom atom(Display *display, const char *name)
{
    return XInternAtom(display, name, False);
}

static int window_manager_ready(Display *display, Window root)
{
    Atom actual_type;
    int actual_format;
    unsigned long count;
    unsigned long remaining;
    unsigned char *data = NULL;
    int status;

    status = XGetWindowProperty(display, root,
                                atom(display, "_NET_SUPPORTING_WM_CHECK"),
                                0, 1, False, XA_WINDOW, &actual_type,
                                &actual_format, &count, &remaining, &data);
    if (data)
        XFree(data);

    return status == Success && actual_type == XA_WINDOW &&
           actual_format == 32 && count == 1;
}

static int wait_for_window_manager(Display *display, Window root)
{
    int attempt;

    for (attempt = 0; attempt < 300; attempt++) {
        if (window_manager_ready(display, root))
            return 1;
        usleep(100000);
    }

    return 0;
}

static void set_cardinals(Display *display, Window window, Atom property,
                          const unsigned long *values, int count)
{
    XChangeProperty(display, window, property, XA_CARDINAL, 32,
                    PropModeReplace, (const unsigned char *)values, count);
}

static Window create_dock(Display *display, Window root, int screen,
                          const char *name, int x, int y,
                          int width, int height,
                          int left, int right, int top, int bottom)
{
    Atom window_type = atom(display, "_NET_WM_WINDOW_TYPE");
    Atom dock_type = atom(display, "_NET_WM_WINDOW_TYPE_DOCK");
    Atom state = atom(display, "_NET_WM_STATE");
    Atom above = atom(display, "_NET_WM_STATE_ABOVE");
    Atom strut = atom(display, "_NET_WM_STRUT");
    Atom strut_partial = atom(display, "_NET_WM_STRUT_PARTIAL");
    Atom pid_atom = atom(display, "_NET_WM_PID");
    unsigned long pid = (unsigned long)getpid();
    unsigned long strut_values[4] = {
        (unsigned long)left,
        (unsigned long)right,
        (unsigned long)top,
        (unsigned long)bottom,
    };
    unsigned long partial_values[12] = {
        (unsigned long)left,
        (unsigned long)right,
        (unsigned long)top,
        (unsigned long)bottom,
        0,
        (unsigned long)(DisplayHeight(display, screen) - 1),
        0,
        (unsigned long)(DisplayHeight(display, screen) - 1),
        0,
        (unsigned long)(DisplayWidth(display, screen) - 1),
        0,
        (unsigned long)(DisplayWidth(display, screen) - 1),
    };
    XSizeHints size_hints;
    XClassHint class_hint;
    Window window;

    window = XCreateSimpleWindow(display, root, x, y,
                                 (unsigned int)width, (unsigned int)height,
                                 0, BlackPixel(display, screen),
                                 BlackPixel(display, screen));
    XStoreName(display, window, name);

    class_hint.res_name = (char *)"equuleus-display-safe-area";
    class_hint.res_class = (char *)"EquuleusDisplaySafeArea";
    XSetClassHint(display, window, &class_hint);

    memset(&size_hints, 0, sizeof(size_hints));
    size_hints.flags = PPosition | PSize | PMinSize | PMaxSize;
    size_hints.x = x;
    size_hints.y = y;
    size_hints.width = width;
    size_hints.height = height;
    size_hints.min_width = width;
    size_hints.max_width = width;
    size_hints.min_height = height;
    size_hints.max_height = height;
    XSetWMNormalHints(display, window, &size_hints);

    XChangeProperty(display, window, window_type, XA_ATOM, 32,
                    PropModeReplace, (unsigned char *)&dock_type, 1);
    XChangeProperty(display, window, state, XA_ATOM, 32,
                    PropModeReplace, (unsigned char *)&above, 1);
    set_cardinals(display, window, strut, strut_values, 4);
    set_cardinals(display, window, strut_partial, partial_values, 12);
    set_cardinals(display, window, pid_atom, &pid, 1);

    XSelectInput(display, window, StructureNotifyMask);
    XMapRaised(display, window);
    return window;
}

int main(int argc, char **argv)
{
    int left = read_option(argc, argv, "--left", 1);
    int right = read_option(argc, argv, "--right", 1);
    int top = read_option(argc, argv, "--top", 0);
    int bottom = read_option(argc, argv, "--bottom", 0);
    int physical_width = read_option(argc, argv, "--physical-width", 1);
    int physical_height = read_option(argc, argv, "--physical-height", 1);
    int logical_width = physical_width - left - right;
    int logical_height = physical_height - top - bottom;
    struct pollfd poll_fd;
    Display *display;
    Window root;
    int screen;
    int width;
    int height;

    if (logical_width <= 0 || logical_height <= 0) {
        fprintf(stderr, "safe insets consume the complete display\n");
        return EXIT_FAILURE;
    }

    display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "cannot open X display\n");
        return EXIT_FAILURE;
    }

    screen = DefaultScreen(display);
    root = RootWindow(display, screen);
    width = DisplayWidth(display, screen);
    height = DisplayHeight(display, screen);

    if (width == logical_width && height == logical_height) {
        XCloseDisplay(display);
        return EXIT_SUCCESS;
    }

    if (width != physical_width || height != physical_height) {
        fprintf(stderr, "unexpected X geometry: %dx%d, expected %dx%d\n",
                width, height, physical_width, physical_height);
        XCloseDisplay(display);
        return EXIT_FAILURE;
    }

    if (!wait_for_window_manager(display, root)) {
        fprintf(stderr, "window manager did not become ready\n");
        XCloseDisplay(display);
        return EXIT_FAILURE;
    }

    if (left)
        create_dock(display, root, screen, "Equuleus left safe area",
                    0, 0, left, height, left, 0, 0, 0);
    if (right)
        create_dock(display, root, screen, "Equuleus right safe area",
                    width - right, 0, right, height, 0, right, 0, 0);
    if (top)
        create_dock(display, root, screen, "Equuleus top safe area",
                    0, 0, width, top, 0, 0, top, 0);
    if (bottom)
        create_dock(display, root, screen, "Equuleus bottom safe area",
                    0, height - bottom, width, bottom, 0, 0, 0, bottom);

    XSync(display, False);
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    poll_fd.fd = ConnectionNumber(display);
    poll_fd.events = POLLIN;
    while (running) {
        int status = poll(&poll_fd, 1, 1000);

        if (status < 0) {
            if (errno == EINTR)
                continue;
            perror("poll");
            break;
        }
        if (status > 0 && (poll_fd.revents & (POLLERR | POLLHUP | POLLNVAL)))
            break;
        while (XPending(display)) {
            XEvent event;

            XNextEvent(display, &event);
        }
    }

    XCloseDisplay(display);
    return running ? EXIT_FAILURE : EXIT_SUCCESS;
}
