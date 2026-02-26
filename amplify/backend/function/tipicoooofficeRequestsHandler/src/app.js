const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand, PutCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const awsServerlessExpressMiddleware = require('aws-serverless-express/middleware');
const bodyParser = require('body-parser');
const express = require('express');
const { v4: uuidv4 } = require('uuid');

// DynamoDB setup
const ddbClient = new DynamoDBClient({ region: process.env.TABLE_REGION });
const ddbDocClient = DynamoDBDocumentClient.from(ddbClient);

let tableName = "AdminRequests";
if (process.env.ENV && process.env.ENV !== "NONE") {
  tableName = `${tableName}-${process.env.ENV}`;
}

const app = express();
app.use(bodyParser.json());
app.use(awsServerlessExpressMiddleware.eventContext());

// CORS
app.use(function (req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "*");
  next();
});

/* -----------------------------------------
   GET /requests
   Restituisce tutte le richieste
----------------------------------------- */
app.get('/requests', async (req, res) => {
  try {
    const data = await ddbDocClient.send(new ScanCommand({
      TableName: tableName
    }));
    res.json(data.Items || []);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* -----------------------------------------
   POST /requests
   Crea una nuova richiesta
----------------------------------------- */
app.post('/requests', async (req, res) => {
  try {
    const { email, roleRequested } = req.body;

    if (!email || !roleRequested) {
      return res.status(400).json({ error: "email e roleRequested sono obbligatori" });
    }

    const now = new Date().toISOString();
    const item = {
      requestId: uuidv4(),
      email,
      roleRequested,
      status: "pending",
      createdAt: now,
      updatedAt: now
    };

    await ddbDocClient.send(new PutCommand({
      TableName: tableName,
      Item: item
    }));

    res.json(item);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* -----------------------------------------
   POST /requests/:id/approve
   Approva una richiesta
----------------------------------------- */
app.post('/requests/:id/approve', async (req, res) => {
  try {
    const requestId = req.params.id;

    const result = await ddbDocClient.send(new UpdateCommand({
      TableName: tableName,
      Key: { requestId },
      UpdateExpression: "set #s = :approved, updatedAt = :now",
      ExpressionAttributeNames: { "#s": "status" },
      ExpressionAttributeValues: {
        ":approved": "approved",
        ":now": new Date().toISOString()
      },
      ReturnValues: "ALL_NEW"
    }));

    res.json(result.Attributes);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* -----------------------------------------
   POST /requests/:id/reject
   Rifiuta una richiesta
----------------------------------------- */
app.post('/requests/:id/reject', async (req, res) => {
  try {
    const requestId = req.params.id;

    const result = await ddbDocClient.send(new UpdateCommand({
      TableName: tableName,
      Key: { requestId },
      UpdateExpression: "set #s = :rejected, updatedAt = :now",
      ExpressionAttributeNames: { "#s": "status" },
      ExpressionAttributeValues: {
        ":rejected": "rejected",
        ":now": new Date().toISOString()
      },
      ReturnValues: "ALL_NEW"
    }));

    res.json(result.Attributes);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(3000, () => {
  console.log("App started");
});

module.exports = app;