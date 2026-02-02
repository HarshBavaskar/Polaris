import json
import os
from valkey import Valkey

CHANNEL = os.getenv("POLARIS_VALKEY_CHANNEL", "polaris:decisions")

def get_client() -> Valkey:
    host = os.getenv("VALKEY_HOST", "localhost")
    port = int(os.getenv("VALKEY_PORT", "6379"))
    return Valkey(host=host, port=port, decode_responses=True)

def publish_decision(decision: dict) -> None:
    """
    Publish the final decision JSON to Valkey Pub/Sub.
    """
    client = get_client()
    client.publish(CHANNEL, json.dumps(decision))