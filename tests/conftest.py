import unittest

# Aliases removidos no Python 3.12
if not hasattr(unittest.TestCase, "assertEquals"):
    unittest.TestCase.assertEquals = unittest.TestCase.assertEqual
if not hasattr(unittest.TestCase, "assertNotEquals"):
    unittest.TestCase.assertNotEquals = unittest.TestCase.assertNotEqual
