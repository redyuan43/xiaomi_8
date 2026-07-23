// SPDX-License-Identifier: GPL-2.0
/*
 * Samsung S5K3T1 front camera sensor for Xiaomi Mi 8 Pro.
 */

#include <linux/clk.h>
#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/pm_runtime.h>
#include <linux/regulator/consumer.h>
#include <media/v4l2-async.h>
#include <media/v4l2-cci.h>
#include <media/v4l2-ctrls.h>
#include <media/v4l2-fwnode.h>
#include <media/v4l2-subdev.h>

#define S5K3T1_NUM_SUPPLIES	3
#define S5K3T1_WIDTH		2592U
#define S5K3T1_HEIGHT		1940U
#define S5K3T1_LINK_FREQ	267000000LL
#define S5K3T1_PIXEL_RATE	213600000LL
#define S5K3T1_MBUS_CODE	MEDIA_BUS_FMT_SGRBG10_1X10

struct s5k3t1 {
	struct v4l2_subdev sd;
	struct media_pad pad;
	struct v4l2_ctrl_handler ctrl_handler;
	struct v4l2_ctrl *link_freq;
	struct v4l2_ctrl *pixel_rate;
	struct mutex mutex;
	struct regmap *regmap;
	struct regulator_bulk_data supplies[S5K3T1_NUM_SUPPLIES];
	struct clk *clk;
	struct gpio_desc *reset_gpio;
	u32 csi2_flags;
	bool initialized;
	bool streaming;
};

static const char * const s5k3t1_supply_names[] = {
	"vana",
	"vdig",
	"vif",
};

static const s64 s5k3t1_link_freq_menu[] = {
	S5K3T1_LINK_FREQ,
};

#include "s5k3t1-vendor-tables.h"

static inline struct s5k3t1 *to_s5k3t1(struct v4l2_subdev *sd)
{
	return container_of(sd, struct s5k3t1, sd);
}

static int s5k3t1_power_on(struct device *dev)
{
	struct v4l2_subdev *sd = dev_get_drvdata(dev);
	struct s5k3t1 *s5k3t1 = to_s5k3t1(sd);
	int ret;

	gpiod_set_value_cansleep(s5k3t1->reset_gpio, 1);

	ret = regulator_bulk_enable(S5K3T1_NUM_SUPPLIES, s5k3t1->supplies);
	if (ret)
		return ret;

	usleep_range(2000, 2500);

	ret = clk_prepare_enable(s5k3t1->clk);
	if (ret) {
		regulator_bulk_disable(S5K3T1_NUM_SUPPLIES, s5k3t1->supplies);
		return ret;
	}

	usleep_range(5000, 6000);
	gpiod_set_value_cansleep(s5k3t1->reset_gpio, 0);
	usleep_range(2000, 2500);

	return 0;
}

static int s5k3t1_power_off(struct device *dev)
{
	struct v4l2_subdev *sd = dev_get_drvdata(dev);
	struct s5k3t1 *s5k3t1 = to_s5k3t1(sd);

	clk_disable_unprepare(s5k3t1->clk);
	gpiod_set_value_cansleep(s5k3t1->reset_gpio, 1);
	regulator_bulk_disable(S5K3T1_NUM_SUPPLIES, s5k3t1->supplies);
	s5k3t1->initialized = false;

	return 0;
}

static int s5k3t1_identify(struct s5k3t1 *s5k3t1)
{
	struct i2c_client *client = v4l2_get_subdevdata(&s5k3t1->sd);
	u64 high;
	u64 low;
	int ret;

	ret = cci_read(s5k3t1->regmap, CCI_REG8(0x0000), &high, NULL);
	if (ret)
		return ret;

	ret = cci_read(s5k3t1->regmap, CCI_REG8(0x0001), &low, NULL);
	if (ret)
		return ret;

	dev_info(&client->dev, "S5K3T1 chip id 0x%02llx%02llx at 0x%02x\n",
		 high, low, client->addr);

	return 0;
}

static int s5k3t1_write_global_settings(struct s5k3t1 *s5k3t1)
{
	return cci_multi_reg_write(s5k3t1->regmap, s5k3t1_vendor_global_regs,
				   ARRAY_SIZE(s5k3t1_vendor_global_regs), NULL);
}

static int s5k3t1_start_streaming(struct s5k3t1 *s5k3t1)
{
	int ret;

	if (!s5k3t1->initialized) {
		ret = s5k3t1_write_global_settings(s5k3t1);
		if (ret)
			return ret;
		s5k3t1->initialized = true;
	}

	ret = cci_multi_reg_write(s5k3t1->regmap, s5k3t1_vendor_preview_regs,
				  ARRAY_SIZE(s5k3t1_vendor_preview_regs), NULL);
	if (ret)
		return ret;

	usleep_range(5000, 6000);
	ret = cci_write(s5k3t1->regmap, CCI_REG8(0x0100), 0x01, NULL);
	if (ret)
		return ret;

	usleep_range(5000, 6000);
	return 0;
}

static void s5k3t1_stop_streaming(struct s5k3t1 *s5k3t1)
{
	int ret;

	ret = cci_write(s5k3t1->regmap, CCI_REG8(0x0100), 0x00, NULL);
	if (ret)
		dev_warn(s5k3t1->sd.dev, "failed to stop stream: %d\n", ret);
}

static void s5k3t1_update_format(struct v4l2_subdev_format *fmt)
{
	fmt->format.width = S5K3T1_WIDTH;
	fmt->format.height = S5K3T1_HEIGHT;
	fmt->format.code = S5K3T1_MBUS_CODE;
	fmt->format.field = V4L2_FIELD_NONE;
}

static int s5k3t1_open(struct v4l2_subdev *sd, struct v4l2_subdev_fh *fh)
{
	struct v4l2_mbus_framefmt *try_fmt;
	struct v4l2_subdev_format fmt = {
		.which = V4L2_SUBDEV_FORMAT_TRY,
		.pad = 0,
	};

	s5k3t1_update_format(&fmt);
	try_fmt = v4l2_subdev_get_try_format(sd, fh->pad, 0);
	*try_fmt = fmt.format;

	return 0;
}

static int s5k3t1_enum_mbus_code(struct v4l2_subdev *sd,
				  struct v4l2_subdev_pad_config *cfg,
				  struct v4l2_subdev_mbus_code_enum *code)
{
	if (code->index)
		return -EINVAL;

	code->code = S5K3T1_MBUS_CODE;
	return 0;
}

static int s5k3t1_enum_frame_size(struct v4l2_subdev *sd,
				   struct v4l2_subdev_pad_config *cfg,
				   struct v4l2_subdev_frame_size_enum *fse)
{
	if (fse->index || fse->code != S5K3T1_MBUS_CODE)
		return -EINVAL;

	fse->min_width = S5K3T1_WIDTH;
	fse->max_width = S5K3T1_WIDTH;
	fse->min_height = S5K3T1_HEIGHT;
	fse->max_height = S5K3T1_HEIGHT;

	return 0;
}

static int s5k3t1_get_format(struct v4l2_subdev *sd,
			      struct v4l2_subdev_pad_config *cfg,
			      struct v4l2_subdev_format *fmt)
{
	if (fmt->which == V4L2_SUBDEV_FORMAT_TRY)
		fmt->format = *v4l2_subdev_get_try_format(sd, cfg, fmt->pad);
	else
		s5k3t1_update_format(fmt);

	return 0;
}

static int s5k3t1_set_format(struct v4l2_subdev *sd,
			      struct v4l2_subdev_pad_config *cfg,
			      struct v4l2_subdev_format *fmt)
{
	s5k3t1_update_format(fmt);
	if (fmt->which == V4L2_SUBDEV_FORMAT_TRY)
		*v4l2_subdev_get_try_format(sd, cfg, fmt->pad) = fmt->format;

	return 0;
}

static int s5k3t1_set_stream(struct v4l2_subdev *sd, int enable)
{
	struct s5k3t1 *s5k3t1 = to_s5k3t1(sd);
	struct i2c_client *client = v4l2_get_subdevdata(sd);
	int ret = 0;

	mutex_lock(&s5k3t1->mutex);

	if (enable) {
		if (s5k3t1->streaming)
			goto unlock;

		ret = pm_runtime_resume_and_get(&client->dev);
		if (ret < 0)
			goto unlock;

		ret = s5k3t1_start_streaming(s5k3t1);
		if (ret) {
			pm_runtime_put(&client->dev);
			goto unlock;
		}
		s5k3t1->streaming = true;
	} else if (s5k3t1->streaming) {
		s5k3t1_stop_streaming(s5k3t1);
		s5k3t1->streaming = false;
		pm_runtime_put(&client->dev);
	}

unlock:
	mutex_unlock(&s5k3t1->mutex);
	return ret;
}

static const struct v4l2_subdev_video_ops s5k3t1_video_ops = {
	.s_stream = s5k3t1_set_stream,
};

static const struct v4l2_subdev_pad_ops s5k3t1_pad_ops = {
	.enum_mbus_code = s5k3t1_enum_mbus_code,
	.enum_frame_size = s5k3t1_enum_frame_size,
	.get_fmt = s5k3t1_get_format,
	.set_fmt = s5k3t1_set_format,
};

static const struct v4l2_subdev_ops s5k3t1_subdev_ops = {
	.video = &s5k3t1_video_ops,
	.pad = &s5k3t1_pad_ops,
};

static const struct v4l2_subdev_internal_ops s5k3t1_internal_ops = {
	.open = s5k3t1_open,
};

static int s5k3t1_init_controls(struct s5k3t1 *s5k3t1)
{
	struct v4l2_ctrl_handler *handler = &s5k3t1->ctrl_handler;
	int ret;

	v4l2_ctrl_handler_init(handler, 2);
	handler->lock = &s5k3t1->mutex;

	s5k3t1->link_freq = v4l2_ctrl_new_int_menu(handler, NULL,
						    V4L2_CID_LINK_FREQ, 0, 0,
						    s5k3t1_link_freq_menu);
	if (s5k3t1->link_freq)
		s5k3t1->link_freq->flags |= V4L2_CTRL_FLAG_READ_ONLY;

	s5k3t1->pixel_rate = v4l2_ctrl_new_std(handler, NULL,
						V4L2_CID_PIXEL_RATE,
						S5K3T1_PIXEL_RATE,
						S5K3T1_PIXEL_RATE, 1,
						S5K3T1_PIXEL_RATE);

	ret = handler->error;
	if (ret) {
		v4l2_ctrl_handler_free(handler);
		return ret;
	}

	s5k3t1->sd.ctrl_handler = handler;
	return 0;
}

static int s5k3t1_probe(struct i2c_client *client,
			 const struct i2c_device_id *id)
{
	struct s5k3t1 *s5k3t1;
	struct fwnode_handle *endpoint;
	struct v4l2_fwnode_endpoint ep = {
		.bus_type = V4L2_MBUS_CSI2_DPHY,
	};
	u32 clock_frequency;
	unsigned int i;
	int ret;

	s5k3t1 = devm_kzalloc(&client->dev, sizeof(*s5k3t1), GFP_KERNEL);
	if (!s5k3t1)
		return -ENOMEM;

	s5k3t1->regmap = devm_cci_regmap_init_i2c(client, 16);
	if (IS_ERR(s5k3t1->regmap))
		return PTR_ERR(s5k3t1->regmap);

	for (i = 0; i < S5K3T1_NUM_SUPPLIES; i++)
		s5k3t1->supplies[i].supply = s5k3t1_supply_names[i];

	ret = devm_regulator_bulk_get(&client->dev, S5K3T1_NUM_SUPPLIES,
				      s5k3t1->supplies);
	if (ret)
		return ret;

	s5k3t1->clk = devm_clk_get(&client->dev, "xvclk");
	if (IS_ERR(s5k3t1->clk))
		return PTR_ERR(s5k3t1->clk);

	if (!device_property_read_u32(&client->dev, "clock-frequency",
				      &clock_frequency)) {
		ret = clk_set_rate(s5k3t1->clk, clock_frequency);
		if (ret)
			return ret;
	}

	s5k3t1->reset_gpio = devm_gpiod_get(&client->dev, "reset",
					     GPIOD_OUT_HIGH);
	if (IS_ERR(s5k3t1->reset_gpio))
		return PTR_ERR(s5k3t1->reset_gpio);

	endpoint = fwnode_graph_get_next_endpoint(dev_fwnode(&client->dev), NULL);
	if (!endpoint)
		return -EINVAL;

	ret = v4l2_fwnode_endpoint_alloc_parse(endpoint, &ep);
	fwnode_handle_put(endpoint);
	if (ret)
		return ret;

	if (ep.bus_type != V4L2_MBUS_CSI2_DPHY ||
	    ep.bus.mipi_csi2.num_data_lanes != 4) {
		ret = -EINVAL;
		goto error_endpoint;
	}
	s5k3t1->csi2_flags = ep.bus.mipi_csi2.flags;

	v4l2_i2c_subdev_init(&s5k3t1->sd, client, &s5k3t1_subdev_ops);
	mutex_init(&s5k3t1->mutex);

	ret = s5k3t1_power_on(&client->dev);
	if (ret)
		goto error_mutex;

	ret = s5k3t1_identify(s5k3t1);
	if (ret)
		goto error_power;

	ret = s5k3t1_init_controls(s5k3t1);
	if (ret)
		goto error_power;

	s5k3t1->sd.internal_ops = &s5k3t1_internal_ops;
	s5k3t1->sd.flags |= V4L2_SUBDEV_FL_HAS_DEVNODE;
	s5k3t1->sd.entity.function = MEDIA_ENT_F_CAM_SENSOR;
	s5k3t1->pad.flags = MEDIA_PAD_FL_SOURCE;

	ret = media_entity_pads_init(&s5k3t1->sd.entity, 1, &s5k3t1->pad);
	if (ret)
		goto error_controls;

	ret = v4l2_async_register_subdev_sensor_common(&s5k3t1->sd);
	if (ret)
		goto error_entity;

	pm_runtime_set_active(&client->dev);
	pm_runtime_enable(&client->dev);
	pm_runtime_idle(&client->dev);
	v4l2_fwnode_endpoint_free(&ep);

	return 0;

error_entity:
	media_entity_cleanup(&s5k3t1->sd.entity);
error_controls:
	v4l2_ctrl_handler_free(&s5k3t1->ctrl_handler);
error_power:
	s5k3t1_power_off(&client->dev);
error_mutex:
	mutex_destroy(&s5k3t1->mutex);
error_endpoint:
	v4l2_fwnode_endpoint_free(&ep);
	return ret;
}

static int s5k3t1_remove(struct i2c_client *client)
{
	struct v4l2_subdev *sd = i2c_get_clientdata(client);
	struct s5k3t1 *s5k3t1 = to_s5k3t1(sd);

	v4l2_async_unregister_subdev(sd);
	media_entity_cleanup(&sd->entity);
	v4l2_ctrl_handler_free(&s5k3t1->ctrl_handler);
	mutex_destroy(&s5k3t1->mutex);

	pm_runtime_disable(&client->dev);
	if (!pm_runtime_status_suspended(&client->dev))
		s5k3t1_power_off(&client->dev);
	pm_runtime_set_suspended(&client->dev);

	return 0;
}

static const struct dev_pm_ops s5k3t1_pm_ops = {
	SET_RUNTIME_PM_OPS(s5k3t1_power_off, s5k3t1_power_on, NULL)
};

static const struct of_device_id s5k3t1_of_match[] = {
	{ .compatible = "samsung,s5k3t1" },
	{ }
};
MODULE_DEVICE_TABLE(of, s5k3t1_of_match);

static struct i2c_driver s5k3t1_i2c_driver = {
	.driver = {
		.name = "s5k3t1",
		.pm = &s5k3t1_pm_ops,
		.of_match_table = s5k3t1_of_match,
	},
	.probe = s5k3t1_probe,
	.remove = s5k3t1_remove,
};
module_i2c_driver(s5k3t1_i2c_driver);

MODULE_DESCRIPTION("Samsung S5K3T1 camera sensor driver");
MODULE_LICENSE("GPL");
