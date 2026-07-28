"""Setup for tap-hr-api."""
from setuptools import setup, find_packages

setup(
    name="tap-hr-api",
    version="0.1.0",
    description="Singer tap for SSI HR API",
    author="Data Engineering",
    url="https://github.com/ssi/data-platform",
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        "singer-sdk>=0.36.0",
        "requests>=2.31.0",
        "PyJWT>=2.8.0",
    ],
    entry_points={
        "console_scripts": [
            "tap-hr-api = tap_hr_api.tap:TapHRApi.cli",
        ],
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
    ],
    python_requires=">=3.9",
)
