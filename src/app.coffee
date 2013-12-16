#!/usr/bin/env coffee

express = require 'express'
api = require "./api"

# vars 
app = express()

# middlewares 
app.use("/public", express.static("#{__dirname}/../public"))
# app.use(express.bodyParser())
app.use(express.urlencoded())
app.use(express.json())

# api
app.post    '/api/query',                   api.query
app.post    '/api/query/fast',              api.fastQuery
app.post    '/api/query/refine',            api.refineQuery
app.get     '/api/search/concepts/:term',   api.searchConcept
app.get     '/api/search/concepts',         api.searchConcept
app.get     '/api/concepts/:id',            api.conceptInfos

module.exports = app

if require.main is module
    config = require './config'
    app.listen(config.port)