from setuptools import setup, find_packages

setup(
    name="audio-stream-client",
    version="1.0.0",
    description="Audio Stream Cache Client - Python Implementation",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[
        "websockets>=12.0",
        "loguru>=0.7.0",
    ],
    entry_points={
        "console_scripts": [
            "audio-stream-client=audio_client.audio_client_application:main",
            "audio-stream-server=audio_server.audio_server_application:main",
        ],
    },
    python_requires=">=3.8",
)
