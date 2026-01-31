# app/notifications/test_alert_engine.py

from app.notifications.alert_engine import build_alert_payload


def run_tests():
    # INFO → None
    assert build_alert_payload({"final_alert_severity": "INFO"}) is None

    # WARNING → payload
    p = build_alert_payload({
        "final_alert_severity": "WARNING",
        "final_eta": 30,
        "justification": "Rapid cloud growth",
    })
    assert p["channel"] == "PUSH_SMS"
    assert p["severity"] == "WARNING"
    assert "30" in p["message"]

    # EMERGENCY → payload
    p2 = build_alert_payload({
        "final_alert_severity": "EMERGENCY",
        "final_eta": 10,
        "justification": "Extreme rainfall detected",
    })
    assert p2["channel"] == "ALL_CHANNELS"
    assert p2["severity"] == "EMERGENCY"

    print("All tests passed ")


if __name__ == "__main__":
    run_tests()