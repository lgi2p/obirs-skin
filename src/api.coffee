
ObirsEngine = require './obirs-engine'
config = require '../config.json'

obirs = new ObirsEngine config

# Example query: 
#
#     query = {
#         concepts: [{id: "D015373", "weight": 0.5},{id:"D006801", "weight": 0.5}],
#         numberOfResults: 30,
#         scoreThreshold: 0.0,
#         aggregatorParameter: 2
#     }
exports.query = (req, res) ->

    try
        query = JSON.stringify req.body
    catch parsingError
        return res.json {error: "Bad query: cannot parse JSON (#{parsingError.message}"}
    try
        obirs.query query, {fast: false}, (err, results) ->
            if err
                return res.send(err.message)
            return res.json(results)
    catch error
        return res.json({error: error.message})


# Example query: 
#
#     query = {
#         concepts: [{id: "D015373", "weight": 0.5},{id:"D006801", "weight": 0.5}],
#         numberOfResults: 30,
#         scoreThreshold: 0.0,
#         aggregatorParameter: 2
#     }
exports.fastQuery = (req, res) ->
    try
        query = JSON.stringify req.body
    catch parsingError
        return res.json {error: "Bad query: cannot parse JSON (#{parsingError.message}"}
    try
        obirs.fastQuery query, {fast: true}, (err, results) ->
            if err
                return res.send(err.message)
            return res.json(results)
    catch error
        return res.json({error: error.message})


# refine a query. Example query:
#
#     query = {
#         query: {
#             concepts: [{id: "D015373", "weight": 0.5},{id:"D006801", "weight": 0.5}]
#         },
#         selectedDocIds: ["1234", "432"],
#         otherDocIds: ["42384", "38403"]
#     }
# '{"query": {"concepts": [{"id": "D015373", "weight": 0.5},{"id":"D006801", "weight": 0.5}] }, "selectedDocIds": ["286", "297", "300"], "otherDocIds": ["295"]}'
exports.refineQuery = (req, res) ->

    try
        query = JSON.stringify req.body
    catch parsingError
        return res.json {error: "Bad query: cannot parse JSON (#{parsingError.message}"}
    try
        obirs.refineQuery query, (err, results) ->
            if err
                return res.send(err.message)
            return res.json(results)
    catch error
        return res.json({error: error.message}) 


exports.searchConcept = (req, res) ->
    term = req.params.term or req.query.term
    obirs.searchConcept term, (err, results) ->
        if err
            return res.send(err.message)
        return res.json(results)


exports.conceptInfos = (req, res) ->
    conceptId = req.params.id
    obirs.conceptInfos conceptId, (err, results) ->
        if err
            return res.send(err.message)
        return res.json(results)
