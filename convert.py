#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import pandas as pd

args = sys.argv
SOURCE_FILE = args[1]
SOURCE_DELIMITER = args[2] if len(args) >= 2 else 'þ'
DESTINATION_FILE = args[3] if len(args) >= 3 else args[1] + '.csv'

df = pd.read_csv(SOURCE_FILE, delimiter=SOURCE_DELIMITER);
df.to_csv(DESTINATION_FILE, index=False, quoting=1)
