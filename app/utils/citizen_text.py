def citizen_eta_message(eta, alert_severity):
    if eta == "UNKNOWN":
        return "Weather conditions are being monitored. No immediate danger detected."

    if alert_severity == "EMERGENCY":
        return f"Severe rainfall likely in {eta}. Please move to a safe location immediately."

    if alert_severity == "ALERT":
        return f"Heavy rainfall may begin in {eta}. Stay alert and avoid low-lying areas."

    if alert_severity == "ADVISORY":
        return f"Weather conditions may worsen in {eta}. Stay cautious."

    return "Conditions are currently stable."
