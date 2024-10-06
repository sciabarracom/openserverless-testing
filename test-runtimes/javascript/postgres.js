/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
const { Client } = require('pg')

async function main(args) {
    console.log(args.postgres_url);

    const client = new Client({connectionString:args.postgres_url});

    const createTableText = `
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    CREATE TABLE IF NOT EXISTS nuvolaris_table (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        message varchar(100)        
    );
    `

    const createSchema = `CREATE SCHEMA IF NOT EXISTS nuvolaris;
    SET search_path TO nuvolaris;
    `;

    // Connect to database server
    await client.connect();

    response = {body: {}}

    try {

        await client.query(createSchema)

        await client.query(createTableText)
        console.log("CREATED TABLE");
        const message = "Nuvolaris Postgres is up and running!"
        await client.query('INSERT INTO nuvolaris_table(message) VALUES($1)', [message])
        console.log("INSERTED RECORD");
        const { rows } = await client.query('SELECT * FROM nuvolaris_table')
        console.log(rows)
        await client.query('DROP table nuvolaris_table');
        console.log("DROPPED TABLE");
        await client.query('DROP SCHEMA nuvolaris CASCADE');
        response.body = rows;
    } catch (e) {
        console.log(e);
        throw e
    } finally {
        client.end();
    }

    return response;
}