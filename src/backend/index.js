import express from "express";
import cors from "cors";
import UserRoute from "./routes/UserRoute.js";
import dotenv from "dotenv";

// load .env
dotenv.config()

const BASE_URL_PORT = process.env.BASE_URL_PORT

const app = express();
app.use(cors());
app.use(express.json());
app.use(UserRoute);

app.listen(BASE_URL_PORT, ()=> console.log('Server up and running...'));