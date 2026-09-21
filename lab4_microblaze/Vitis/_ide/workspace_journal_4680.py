# 2026-09-21T10:09:22.954188300
import vitis

client = vitis.create_client()
client.set_workspace(path="Vitis")

platform = client.get_component(name="z7_lite_microblaze")
status = platform.build()

comp = client.get_component(name="z7_running_led")
comp.build()

status = platform.build()

comp.build()

comp = client.get_component(name="z7_running_led")
comp.set_app_config(key = "USER_COMPILE_DEFINITIONS", values = ["SIM_BUILD=1"])

comp = client.get_component(name="z7_running_led")
status = comp.clean()

status = platform.build()

comp.build()

vitis.dispose()

