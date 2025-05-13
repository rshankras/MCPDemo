# MCP Demo Server

This repository contains simple Node.js implementations of Model Context Protocol (MCP) servers for demonstration purposes. The servers provide documentation resources and database access that can be used by your LLM assistant.

## Features

### Documentation Server (`server.js`)
- Provides three documentation resources:
  - Introduction to MCP
  - API Reference
  - Examples

### Database Server (`database-server.js`)
- Provides a SQLite database with employee data
- Exposes database schema documentation
- Supports SQL queries through MCP tools
- Includes sample query examples

## Installation

Make sure you have Node.js installed on your system. Then run:

```bash
npm install
```

This will install the required dependencies:
- better-sqlite3 (for the database server)

## Usage

### Documentation Server

To run the documentation server:

1. Make sure the server.js file is executable:
   ```bash
   chmod +x server.js
   ```

2. Connect to the server from your MCP client application:
   - Server Name: MCP Documentation
   - Executable Path: [Full path to server.js]
   - Arguments: (leave empty)

### Database Server

To run the database server:

1. Make sure the database-server.js file is executable:
   ```bash
   chmod +x database-server.js
   ```

2. Connect to the server from your MCP client application:
   - Server Name: Employee Database
   - Executable Path: [Full path to database-server.js]
   - Arguments: (leave empty)

## Connecting with the MCPDemo Mac App

1. Open the MCPDemo app
2. Click on the network icon in the top toolbar
3. In the "Add New Server" section:
   - Enter "MCP Documentation" or "Employee Database" for Server Name
   - Enter the full path to the server.js or database-server.js file for Executable Path
   - Leave Arguments field empty
4. Click "Connect Server"

Once connected, the app will be able to access the resources through the MCP protocol, and the LLM assistant can use this information when answering your questions.

### Example Interactions

After connecting the database server, you can ask questions like:
- "Show me the database schema"
- "List all employees in the database"
- "What's the average salary by department?"
- "How many people work in Engineering?"

The LLM will use the MCP tools to query the database and provide you with the answers.

## Resources Provided

### Documentation Server

The documentation server creates three Markdown documents:

1. **Introduction to MCP** - A high-level overview of the Model Context Protocol
2. **API Reference** - Documentation on core MCP concepts and protocol flow
3. **Examples** - Code examples showing how to use MCP

### Database Server

The database server provides:

1. **Database Schema** - Documentation of the employee database structure
2. **Sample Data** - Information about the sample data and example queries
3. **Query Tool** - A tool for executing SQL queries against the database

## Protocol Support

These servers implement a simplified version of the MCP protocol with support for:

- Server initialization
- Resource listing
- Resource content reading
- Tool definitions and execution (database server only)

## License

MIT 