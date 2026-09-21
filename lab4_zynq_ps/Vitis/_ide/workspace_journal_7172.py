# 2026-09-20T22:58:45.613148800
import vitis

client = vitis.create_client()
client.set_workspace(path="Vitis")

platform = client.get_component(name="z7_lite_running_light")
status = platform.build()

comp = client.get_component(name="running_light")
comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../Vivado/design_led_chaser_wrapper.xsa")

status = platform.build()

vitis.dispose()

