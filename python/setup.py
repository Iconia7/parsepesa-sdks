from setuptools import setup, find_packages
import os

# Read the contents of your README file
this_directory = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(this_directory, 'README.md'), encoding='utf-8') as f:
    long_description = f.read()

setup(
    name="parsepesa",
    version="1.0.2",
    description="Official Python SDK for ParsePesa - The M-Pesa SMS Parsing API",
    long_description=long_description,
    long_description_content_type='text/markdown',
    packages=find_packages(),
    install_requires=[
        "requests>=2.25.0",
    ],
    author="Nexora Creative Solutions",
    author_email="info@nexoracreatives.co.ke",
    url="https://parsepesa.nexoracreatives.co.ke",
    license="MIT",
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
)
