# 2026-09-21T06:36:24.520259500
import vitis

client = vitis.create_client()
client.set_workspace(path="Vitis")

platform = client.get_component(name="z7_lite_running_light")
status = platform.build()

comp = client.get_component(name="running_light")
comp.build()

status = platform.build()

status = platform.build()

comp.build()

vitis.dispose()

