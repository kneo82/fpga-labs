# 2026-09-21T12:36:02.729288500
import vitis

client = vitis.create_client()
client.set_workspace(path="Vitis")

comp = client.get_component(name="z7_running_led")
comp.set_app_config(key = "USER_COMPILE_DEFINITIONS", values = [""])

platform = client.get_component(name="z7_lite_microblaze")
status = platform.build()

comp = client.get_component(name="z7_running_led")
comp.build()

