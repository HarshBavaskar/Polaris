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
fcm_tokens_collection = db["fcm_tokens"]
safe_zones_collection = db["safe_zones"]
historical_events_collection = db["historical_events"]
overrides_collection = db["overrides"]
safezones_collection = db["safe_zones"]
active_learning_collection = db["active_learning_samples"]

def ensure_safezone_indexes():
    safezones_collection.create_index(
        "expires_at",
        expireAfterSeconds=0
    )
    safezones_collection.create_index(
        [("active", 1), ("confidence_level", 1)]
    )


def ensure_active_learning_indexes():
    active_learning_collection.create_index(
        [("status", 1), ("queued_at", -1)]
    )
    active_learning_collection.create_index(
        [("prediction_id", 1)],
        unique=True
    )


def ensure_fcm_token_indexes():
    fcm_tokens_collection.create_index(
        [("token", 1)],
        unique=True
    )
    fcm_tokens_collection.create_index(
        [("active", 1), ("updated_at", -1)]
    )
