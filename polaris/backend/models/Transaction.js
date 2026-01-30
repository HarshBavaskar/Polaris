import mongoose from "mongoose";

const transactionSchema = new mongoose.Schema({
  user: { type: String, required: true },
  amount: { type: Number, required: true },
  normalizedAmount: { type: Number, required: true },
  isLargeTransaction: { type: Boolean, required: true },
  createdAt: { type: Date, default: Date.now }
});

const Transaction = mongoose.model("Transaction", transactionSchema);
export default Transaction;
