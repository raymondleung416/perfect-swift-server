//
//  main.swift
//  PerfectTemplate
//
//  Created by Kyle Jessup on 2015-11-05.
//	Copyright (C) 2015 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import SQLite
import PerfectMustache

// Create HTTP server.
let server = HTTPServer()

// Register your own routes and handlers
var routes = Routes()
routes.add(method: .get, uri: "/", handler: {
		request, response in
		response.setHeader(.contentType, value: "text/html")
		response.appendBody(string: "<html><title>Hello, Lighthouse!</title><body>Hello, world, Lighthouse!</body></html>")
		response.completed()
	}
)

//routes.add(method: .get, uri: "/JSON") { (request, response) in
//    response.setHeader(.contentType, value: "application/json")
//    let d: [String:Any] = ["key": ["I Love SSS"]]
//
//    do {
//        try response.setBody(json: d)
//    } catch {
//        //...
//    }
//    response.completed()
//}


routes.add(method: .get, uri: "/JSON") { (request, response) in
    response.setHeader(.contentType, value: "application/json")
    var databaseResponse = [String]()

    do {
        let dbPath = "./magic8ball.db"
        let sqlite = try SQLite(dbPath)
        defer {
            sqlite.close()
        }

        let demoStatement = "SELECT * FROM responses"

        try sqlite.forEachRow(statement: demoStatement) {(statement: SQLiteStmt, i:Int) -> () in
            databaseResponse.append(statement.columnText(position: 1))
        }
    } catch {
        print("error with setting up database: \(error)")
    }

    var d = [String:Any]()
    d["key"] = databaseResponse

    do {
        try response.setBody(json: d)
    } catch {
        //...
    }
    response.completed()

}

struct DataModel {

    var responses = [String]();
    var dictionary = [[String:String]]()
    let dbPath = "./magic8ball.db"

    init(){
        do {
            let sqlite = try SQLite(dbPath)
            defer {
                sqlite.close()
            }

            let demoStatement = "SELECT * FROM responses"

            try sqlite.forEachRow(statement: demoStatement) {(statement: SQLiteStmt, i:Int) -> () in
                responses.append(statement.columnText(position: 1))
                dictionary.append([
                    "id": statement.columnText(position: 0),
                    "message": statement.columnText(position: 1)
                ])
            }
        } catch {
            print("error with getting data: \(error)")
        }
    }
}

struct TestHandler: MustachePageHandler {
    func extendValuesForResponse(context contxt: MustacheWebEvaluationContext, collector: MustacheEvaluationOutputCollector) {
        var values = MustacheEvaluationContext.MapType()


        let dataModel = DataModel()
        values["value"] = dataModel.dictionary

        contxt.extendValues(with: values)
        do {
            try contxt.requestCompleted(withCollector: collector)
        } catch {
            let response = contxt.webResponse
            response.status = .internalServerError
            response.appendBody(string: "\(error)")
            response.completed()
        }
    }
}

routes.add(method: .get, uri: "/content", handler: {
    request, response in
    let webRoot = request.documentRoot
    mustacheRequest(request: request, response: response, handler: TestHandler(), templatePath: webRoot + "/content.html")
})


routes.add(method: .post, uri: "/delete", handler: {
    request, response in
    let dbPath = "./magic8ball.db"

    if let givenId = request.param(name: "id") {

        do {
            let sqlite = try SQLite(dbPath)
            defer {
                sqlite.close()
            }

            try sqlite.execute(statement: "DELETE FROM responses WHERE id = '\(givenId)'")

        } catch {
            response.appendBody(string: "fail \(error)")
        }
    }

    response.completed()
})

// Add the routes to the server.
server.addRoutes(routes)

// Set a listen port of 8181
server.serverPort = 8181

// Set a document root.
// This is optional. If you do not want to serve static content then do not set this.
// Setting the document root will automatically add a static file handler for the route /**
server.documentRoot = "./webroot"

// Gather command line options and further configure the server.
// Run the server with --help to see the list of supported arguments.
// Command line arguments will supplant any of the values set above.
configureServer(server)

do {
	// Launch the HTTP server.
	try server.start()
} catch PerfectError.networkError(let err, let msg) {
	print("Network error thrown: \(err) \(msg)")
}
