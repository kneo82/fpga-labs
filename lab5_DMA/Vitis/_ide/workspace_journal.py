# 2026-10-01T16:04:19.628708300
import vitis

client = vitis.create_client()
client.set_workspace(path="Vitis")

platform = client.create_platform_component(name = "lab5_dma",hw_design = "$COMPONENT_LOCATION/../../Vivado/lab5_DMA/design_1_wrapper.xsa",os = "standalone",cpu = "microblaze_0",domain_name = "standalone_microblaze_0",compiler = "gcc")

platform = client.get_component(name="lab5_dma")
status = platform.build()

comp = client.create_app_component(name="dma",platform = "$COMPONENT_LOCATION/../lab5_dma/export/lab5_dma/lab5_dma.xpfm",domain = "standalone_microblaze_0")

status = platform.build()

comp = client.get_component(name="dma")
comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

vitis.dispose()

