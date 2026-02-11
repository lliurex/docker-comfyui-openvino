#!/usr/bin/env python3
from openvino import Core
ie = Core()
print("Devices:", ie.get_available_devices())
