
java = require 'java'
fs = require 'fs'

java.classpath.push("#{__dirname}/../javalib/obirs.jar")
# java.classpath.push("#{__dirname}/../javalib/slib-dist-0.6-all-jar.jar")
ObirsJava = java.import('ema.lgi2p.obirs.ObirsMohameth2010')
# ObirsJava = java.import('ema.lgi2p.obirs.ObirsGroupwise')


# console.log similarityMeasureConf

getObirsInstance = (ontologyFilePath, indexationFilePath, configName) ->
    config = {
        'mohameth2010': () ->
            IC_Conf_Topo = java.import('slib.sml.sm.core.metrics.ic.utils.IC_Conf_Topo')
            SMConstants = java.import('slib.sml.sm.core.utils.SMConstants')
            SMconf = java.import('slib.sml.sm.core.utils.SMconf')
            ObirsJava = java.import('ema.lgi2p.obirs.ObirsMohameth2010')
            icConf = new IC_Conf_Topo(SMConstants.FLAG_ICI_SANCHEZ_2011_a)
            similarityMeasureConf = new SMconf("Lin_icSanchez", SMConstants.FLAG_SIM_PAIRWISE_DAG_NODE_LIN_1998, icConf)
            return new ObirsJava(ontologyFilePath, indexationFilePath, similarityMeasureConf)
        'groupwise-standalone': () ->
            IC_Conf_Topo = java.import('slib.sml.sm.core.metrics.ic.utils.IC_Conf_Topo')
            SMConstants = java.import('slib.sml.sm.core.utils.SMConstants')
            SMconf = java.import('slib.sml.sm.core.utils.SMconf')
            ObirsJava = java.import('ema.lgi2p.obirs.ObirsGroupwise')
            icConf = new IC_Conf_Topo(SMConstants.FLAG_ICI_SECO_2004)
            similarityMeasureConf = new SMconf("", SMConstants.FLAG_SIM_GROUPWISE_DAG_TO, icConf)
            return new ObirsJava(ontologyFilePath, indexationFilePath, similarityMeasureConf)
        'groupwise-addon': () ->
            IC_Conf_Topo = java.import('slib.sml.sm.core.metrics.ic.utils.IC_Conf_Topo')
            SMConstants = java.import('slib.sml.sm.core.utils.SMConstants')
            SMconf = java.import('slib.sml.sm.core.utils.SMconf')
            ObirsJava = java.import('ema.lgi2p.obirs.ObirsGroupwise')
            icConf = new IC_Conf_Topo(SMConstants.FLAG_ICI_SECO_2004)
            pairwiseMeasureConf = new SMconf("", SMConstants.FLAG_SIM_PAIRWISE_DAG_NODE_LIN_1998, icConf)
            groupwiseMeasureConf = new SMconf("", SMConstants.FLAG_SIM_GROUPWISE_BMA, icConf)
            return new ObirsJava(ontologyFilePath, indexationFilePath, groupwiseMeasureConf, pairwiseMeasureConf)
    }

    if configName not of config
         throw "unknown obirs configuration: #{configName}"
    return config[configName]()


sparql = require 'sparql'

async = require 'async'
_ = require 'underscore'

IndexationBuilder = require('./idxbuilder')


module.exports = class ObirsEngine
    
    #
    # Make the bridge beeteen obirs.jar and the front-end.
    # 
    # conf:
    #   * ontologyFilePath: the absolute path to the ontology xml file
    #   * indexationFilePath: the absolute path to the indexation json file
    #   * endpointURI: the url to the sparql endpoint
    #                  (default to http://localhost:8890/sparql)
    #   * graphURI: the uri of the graph
    #   * engine: the engine to use: 'mohameth2010', 'groupwise-standalone', 'groupwise-addon'
    constructor: (options) ->
        @ontologyFilePath = options.ontologyFilePath
        @indexationFilePath = options.indexationFilePath
        @endpointURI = options.endpointURI or 'http://localhost:8890/sparql'
        @graphURI = options.graphURI
        @engineName = options.engine or 'mohameth2010'

        unless @ontologyFilePath
            throw "Obirs error: ontologyFilePath not found"
        unless @indexationFilePath
            throw "Obirs error: indexationFilePath not found"
        unless @graphURI
            throw "Obirs error: graphURI not found"

        @sparqlClient = new sparql.Client @endpointURI

        console.log "launching Obirs..."
        # fetch the data from kalitmo's db and build the indexation file
        if not fs.existsSync(@indexationFilePath)
            console.log "fetching data from kalitmo and building #{@indexationFilePath}..."
            console.log 'please wait, it can take a while...'
            indexationBuilder = new IndexationBuilder
            indexationBuilder.build @indexationFilePath, (err, ok) =>
                if err
                    throw err
                @core = getObirsInstance(@ontologyFilePath, @indexationFilePath, @engineName)
                console.log 'Obirs launched'
        else
            @core = getObirsInstance(@ontologyFilePath, @indexationFilePath, @engineName)
            console.log 'Obirs launched'


    # take a raw sparql query and fetch the data
    sparql: (query, callback) ->
        @sparqlClient.rows query, (err, data) ->
            if err
                return callback err[2]
            return callback null, data


    # Query the indexation via Obirs.
    # The jsonQuery is a regular Obirs query:
    # example:
    #
    #     {"concepts": [
    #       {"id": "http://obirs/D015373", "weight": 0.5},
    #       {"id":"http://obirs/D006801", "weight": 0.5}
    #     ]}
    #
    # If the concept ids are regular IDs (ie not URI), a defaultNameSpace
    # can be specified: 
    #
    #      {
    #           "concepts": [
    #               {"id": "D015373", "weight": 0.5}
    #               {"id": "D006801", "weight": 0.5}
    #           ],
    #           "defaultNameSpace": "http://obirs"
    #      }
    #
    # options:
    #    fast: (default true) if true, perform a fast query
    #
    # callback: (err, {results: data})
    query: (jsonQuery, options, callback) =>
        if not callback and options
            callback = options
            options = {fast: true}
        if options.fast
            queryFn = @core.fastQuery
        else
            queryFn = @core.query
        @core.query jsonQuery, (err, results) =>
            if err
                return callback(err)
            try
                results = JSON.parse(results)
            catch parsingError
                return callback {
                    error: "Bad query, cannot parse JSON (#{parsingError.message})"
                }
            conceptURIs = {}
            for res in results
                if not res?.concepts
                    console.log "XXXX", res
                else
                    for concept in res.concepts
                        conceptURIs[concept.queryConceptURI] = 1
                        conceptURIs[concept.matchingConceptURI] = 1
            conceptIds = (i.split('/')[-1..][0] for i in _.keys(conceptURIs))
            async.map conceptIds, @conceptInfos.bind(@), (err, data) =>
                conceptTitles = {}
                for concept in data
                    conceptTitles["http://obirs/#{concept.results.id}"] = concept.results
                for publication in results
                    for cpt in publication?.concepts or []
                        cpt.queryConcept = conceptTitles[cpt.queryConceptURI]
                        cpt.matchingConcept = conceptTitles[cpt.matchingConceptURI]
                return callback null, {results: results}


    # Performs a regular Obirs fast query
    fastQuery: (jsonQuery, options, callback) =>
        options.fast = true
        @query jsonQuery, options, callback


    # Takes a list of wanted (and unwanted documents) and try to refine the query
    #
    # example of query:
    #   "{
    #       "query": {"concepts": [
    #           {"id": "D015373", "weight": 0.5},
    #           {"id":"D006801", "weight": 0.5}
    #       ]},
    #       "selectedDocIds": ["42172", "42697", "42719"],
    #       "rejectedDocIds": ["42759"]
    #    }"
    #
    refineQuery: (jsonQuery, callback) =>
        @core.refineQuery jsonQuery, (err, data) =>
            if err
                return callback(err)
            try
                results = JSON.parse(data)
            catch parsingError
                return callback {
                    error: "Bad query, cannot parse JSON (#{parsingError.message})"
                }
            conceptIds = (i.id.split('/')[-1..][0] for i in results.concepts)
            async.map conceptIds, @conceptInfos.bind(@), (err, datares) =>
                conceptTitles = {}
                for cpt in datares
                    conceptTitles["http://obirs/#{cpt.results.id}"] = cpt.results.title
                concepts = []
                for concept in results.concepts
                    concept.title = conceptTitles[concept.id]
                    concepts.push concept
                results.concepts = concepts
                return callback null, {results: results}


    # returns a concept info from its id.
    # A concept info take the following form:
    #
    # {
    #    id: concept id
    #    uri: concept uri
    #    title: concept title
    # }
    conceptInfos: (conceptId, callback) =>
        sparqlQuery = """
        SELECT * FROM <#{@graphURI}> WHERE {
           ?uri <http://kalitmo.org/property/id> "#{conceptId}" .
           ?uri <http://purl.org/dc/elements/1.1/title> ?title .
        }
        """
        @sparql sparqlQuery, (err, data) =>
            if err
                return callback err
            results = {}                
            if data.length
                data = data[0]
                results = {
                    uri: data.uri.value
                    title: data.title.value
                    id: conceptId
                }
            return callback null, {results: results}


    # returns all concept from a term
    # The results is a list of concept infos (see `conceptInfos`)
    searchConcept: (term, callback) =>
        if term.length < 3
            return callback null, {results: []}
        sparqlQuery = """
        SELECT * FROM <#{@graphURI}> WHERE {
            ?uri <http://purl.org/dc/elements/1.1/title> ?title .
            FILTER regex(?title, "^#{term}", "i")
            ?uri <http://kalitmo.org/property/id> ?id .
        } LIMIT 20
        """
        @sparql sparqlQuery, (err, data) =>
            if err
                return callback(err)
            results = []
            for row in data
                results.push {
                    uri: row.uri.value
                    title: row.title.value
                    id: row.id.value
                }
            return callback null, {results: results}

