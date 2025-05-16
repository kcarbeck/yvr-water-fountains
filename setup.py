# setup.py
from setuptools import setup, find_packages

setup(
    name="yvr_fountains",
    version="0.0.1",
    package_dir={"": "src"},      # tell setuptools code lives in src/
    packages=find_packages(where="src"),
    python_requires=">=3.9",
    install_requires=[
        "pandas",
        "requests",
        "geojson",
        "folium",
        "click",
    ],
)