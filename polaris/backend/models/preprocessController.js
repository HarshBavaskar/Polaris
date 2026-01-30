import { preprocessData } from "../utils/preprocess.js";
import Transaction from "../models/Transaction.js";

export const preprocess = async (req, res) => {
  try {
    const rawData = req.body;

    if (!Array.isArray(rawData)) {
      return res.status(400).json({ message: "Input must be an array" });
    }

    const processedData = preprocessData(rawData);

    // Save processed data to MongoDB
    const saved = await Transaction.insertMany(processedData);

    res.status(200).json({
      message: "Preprocessing successful and data saved to DB",
      data: saved
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
