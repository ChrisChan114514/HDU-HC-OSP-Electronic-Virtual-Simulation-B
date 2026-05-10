#!/usr/bin/env python3
from PIL import Image
import numpy as np

im = Image.open('rom/preview.png')
arr = np.array(im)
print('shape:', arr.shape)
flat = arr.reshape(-1, 3)
print('min per channel:', flat.min(axis=0))
print('max per channel:', flat.max(axis=0))
print('unique colors:', len({tuple(px) for px in flat}))
