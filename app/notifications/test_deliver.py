import app.notifications.deliver as delivery


def run_tests():
    call_count = {"fcm": 0}

    def fake_fcm(_payload):
        call_count["fcm"] += 1
        return {"ok": True, "provider": "fcm"}

    original_fcm = delivery.send_push_fcm
    delivery.send_push_fcm = fake_fcm

    try:
        for channel in (
            "APP_NOTIFICATION",
            "PUSH_NOTIFICATION",
            "PUSH_SMS",
            "SMS_SIREN",
            "ALL_CHANNELS",
        ):
            response = delivery.deliver({"channel": channel})
            assert response["ok"] is True
            assert response["provider"] == "fcm"

        assert call_count == {"fcm": 5}

        response = delivery.deliver({"channel": "UNKNOWN"})
        assert response["ok"] is False
        assert "No delivery route defined" in response["error"]

        print("All delivery routing tests passed")
    finally:
        delivery.send_push_fcm = original_fcm


if __name__ == "__main__":
    run_tests()
