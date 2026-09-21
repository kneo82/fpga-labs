# 2026-09-21T00:12:06.153069400
import vitis

client = vitis.create_client()
client.set_workspace(path="Vitis")

platform = client.get_component(name="z7_lite_running_light")
status = platform.build()

comp = client.get_component(name="running_light")
comp.build()

domain = platform.get_domain(name="standalone_ps7_cortexa9_0")

status = domain.set_config(option = "os", param = "standalone_stdin", value = "ps7_uart_0")

status = domain.set_config(option = "os", param = "standalone_stdout", value = "ps7_uart_0")

status = platform.build()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../Vivado/design_led_chaser_wrapper.xsa")

status = platform.build()

status = comp.clean()

status = platform.build()

comp.build()

vitis.dispose()

