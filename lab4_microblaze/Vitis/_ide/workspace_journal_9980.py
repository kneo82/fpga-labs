# 2026-09-21T09:05:09.632839200
import vitis

client = vitis.create_client()
client.set_workspace(path="Vitis")

platform = client.create_platform_component(name = "z7_lite_microblaze",hw_design = "$COMPONENT_LOCATION/../../Vivado/z7_light_microblaze_wrapper.xsa",os = "standalone",cpu = "microblaze_0",domain_name = "standalone_microblaze_0",compiler = "gcc")

platform = client.get_component(name="z7_lite_microblaze")
status = platform.build()

comp = client.create_app_component(name="z7_running_led",platform = "$COMPONENT_LOCATION/../z7_lite_microblaze/export/z7_lite_microblaze/z7_lite_microblaze.xpfm",domain = "standalone_microblaze_0")

status = platform.build()

comp = client.get_component(name="z7_running_led")
comp.build()

vitis.dispose()

