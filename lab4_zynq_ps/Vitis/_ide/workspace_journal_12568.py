# 2026-09-20T22:24:05.414378700
import vitis

client = vitis.create_client()
client.set_workspace(path="Vitis")

platform = client.create_platform_component(name = "z7_lite_running_light",hw_design = "$COMPONENT_LOCATION/../../Vivado/design_led_chaser_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0",domain_name = "standalone_ps7_cortexa9_0",compiler = "gcc")

platform = client.get_component(name="z7_lite_running_light")
status = platform.build()

comp = client.create_app_component(name="running_light",platform = "$COMPONENT_LOCATION/../z7_lite_running_light/export/z7_lite_running_light/z7_lite_running_light.xpfm",domain = "standalone_ps7_cortexa9_0")

status = platform.build()

comp = client.get_component(name="running_light")
comp.build()

vitis.dispose()

