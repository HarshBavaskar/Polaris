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

