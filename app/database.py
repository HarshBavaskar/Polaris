from pymongo import MongoClient

MONGO_URL = "mongodb://localhost:27017"

client = MongoClient(MONGO_URL)

db = client["polaris"]

# Collections
images_collection = db["images"]
predictions_collection = db["predictions"]
citizen_reports_collection = db["citizen_reports"]
feedback_collection = db["feedback"]
alerts_collection = db["alerts"]
safe_zones_collection = db["safe_zones"]
historical_events_collection = db["historical_events"]
overrides_collection = db["overrides"]
safezones_collection = db["safe_zones"]

def ensure_safezone_indexes():
    safezones_collection.create_index(
        "expires_at",
        expireAfterSeconds=0
    )
    safezones_collection.create_index(
        [("active", 1), ("confidence_level", 1)]
    )