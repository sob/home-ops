"""Build-time check that SenseLink works on this image's Python.

Loads a config with a static plug and an MQTT plug (broker unreachable), feeds
the MQTT plug a Shelly Gen2+ status/switch:0 payload, then sends the query a
Sense monitor broadcasts and checks both plugs answer with the right watts.
"""
import asyncio
import json
import socket

from senselink import SenseLink
from senselink.mqtt import MQTTSource
from senselink.tplink_encryption import decrypt, encrypt

PORT = 19999
CONFIG = """
sources:
- static:
    plugs:
    - rack:
        alias: Rack
        mac: 53:75:31:00:00:09
        max_watts: 123
- mqtt:
    host: 127.0.0.1
    port: 1
    plugs:
    - sump-pump:
        alias: Sump Pump
        mac: 53:75:31:00:00:01
        power_topic: shelly/sump-pump/status/switch:0
        power_topic_keypath: apower
"""
QUERY = '{"emeter":{"get_realtime":{}},"system":{"get_sysinfo":{}}}'


async def main():
    server = SenseLink(CONFIG, port=PORT)
    server.create_instances()
    mqtt = next(i.data_source for i in server.instances.values()
                if isinstance(i.data_source, MQTTSource))
    mqtt.update_power(json.dumps({"id": 0, "output": True, "apower": 512.3, "voltage": 121.0}))
    task = asyncio.create_task(server.start())
    await asyncio.sleep(1)

    # Non-blocking: the server replies from this same event loop.
    loop = asyncio.get_running_loop()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setblocking(False)
    # SenseLink, like a real HS110, drops the 4-byte length header on UDP.
    sock.sendto(encrypt(QUERY)[4:], ("127.0.0.1", PORT))
    got = {}
    for _ in range(2):
        reply = json.loads(decrypt(await asyncio.wait_for(loop.sock_recv(sock, 4096), 5)))
        got[reply["system"]["get_sysinfo"]["alias"]] = reply["emeter"]["get_realtime"]["power"]
    task.cancel()

    assert got == {"Rack": 123.0, "Sump Pump": 512.3}, got
    print("selftest ok:", got)


asyncio.run(main())
