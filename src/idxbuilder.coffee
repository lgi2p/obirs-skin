#!/usr/bin/env coffee

querystring = require 'querystring'
request = require 'request'
async = require 'async'
fs = require 'fs'
_ = require 'underscore'


module.exports = class IndexationBuilder

    sparql: (query, options, callback) =>
        if not callback and options
            callback = options
            options = null
        opts = {
            uri: 'http://localhost:8890/sparql'
            headers: {
                'content-type':'application/x-www-form-urlencoded'
                'accept':'application/sparql-results+json'
            }
            body: querystring.stringify (query:query)
            encoding: 'utf8'
        }
        if options?.format is 'json'
            opts.headers.accept = 'application/ld+json'
        else if options?.format is 'turtle'
            opts.headers.accept = 'text/ntriples'
        else if options?.format is 'csv'
            opts.headers.accept = 'text/tab-separated-values'
        request.post opts, (err, res, body) =>
            if err
                return callback err
            if options?.format is 'json'
                unless JSON.parse(body)['@graph']?
                    console.log query
                results = JSON.parse(body)['@graph']
                for item in results
                    for key, values of item
                        if values[0]['@value']
                            item[key] = (v['@value'] for v in values)
                return callback null, results
            else if options?.format is 'turtle'
                return callback null, body
            else if options?.format is 'csv'
                try
                    results = @parseCSV body
                catch parseError
                    return callback parseError
                return callback null, results
            else
                try
                    results = JSON.parse(body).results.bindings
                catch e
                    return callback "cannot parse body: #{body}"
            return callback null, results


    parseCSV: (body, callback) =>
        regErr = new RegExp /^Virtuoso\s\w+\sError\s\w+\W\sSPARQL\scompiler/
        if body.search(regErr) > -1
            throw body
        results = []
        lines = body.split('\n')
        csvHead = (h.replace(/\"/g, '') for h in lines.splice(0, 1))
        lines.pop() # remove the empty last line
        for line in lines
            fields = (i.replace(/\"/g, '') for i in line.split('"\t"'))
            results.push _.object( csvHead, fields)
        return results
    

    # fetch a document by its id
    fetchByidOld: (id, callback) =>
        # uris = ("<#{id}>" for id in ids).join(', ')
        @sparql "SELECT * WHERE {<#{id}> ?p ?o . }", (err, data) ->
            if err
                return callback err
            results = {id: id}
            for item in data
                unless results[item.p.value]
                    results[item.p.value] = []
                if item.o.value not in results[item.p.value]
                    results[item.p.value].push item.o.value
            return callback null, results


    fetchByids: (ids, callback) =>
        return callback(null, []) unless ids
        uris = ("<#{id}>" for id in ids).join(',')
        unless uris.length
            return callback null, []
        @sparql """CONSTRUCT {
            ?s ?p ?o .
        } WHERE {
            ?s ?p ?o . 
            FILTER (?s IN(#{uris}))
        }""", {format: 'json'}, (err, data) =>
            if err
                return callback err
            return callback null, data


    # returns a subset of publications
    _nextIds: (skip, callback) =>
        @sparql """
            SELECT ?id FROM <http://kalitmo.org/itcancer> WHERE {
                ?id a <http://kalitmo.org/type/Publication> .
            } OFFSET #{skip} LIMIT 30
        """, {format: 'csv'}, (err, data) ->
            if err
                return callback err
            return callback null, (item.id for item in data)


    # replace all concept ids by the related document in a publication
    _fillConcept: (publication, callback) =>
        conceptURIs = publication['http://kalitmo.org/property/mesh_concept']
        unless conceptURIs?.length
            publication['http://kalitmo.org/property/mesh_concept'] = []
            return callback null, publication
        @fetchByids conceptURIs, (err, concepts) =>
            if err
                return callback err
            conceptIds = _.flatten (c['http://kalitmo.org/property/id'] for c in concepts)
            publication['http://kalitmo.org/property/mesh_concept'] = conceptIds
            return callback null, publication


    # returns the number of publications
    count: (callback) =>
        @sparql """ SELECT count(*) FROM <http://kalitmo.org/itcancer> WHERE {
            ?s a <http://kalitmo.org/type/Publication> .
        }""", (err, data) ->
            if err
                return callback err
            return callback null, data[0]['callret-0'].value


    # returns all publications ids
    all: (callback) =>
        @count (err, total) =>
            if err
                return callback err

            indices = []
            for i in [0..total] by 30
                indices.push i

            async.mapLimit indices, 5, @_nextIds, (err, publicationIds) =>
                # publicationIds = _.uniq(_.flatten(publicationIds))
                async.mapLimit publicationIds, 5, @fetchByids, (err, publicationData) =>
                    if err
                        return callback err
                    publications = _.flatten publicationData
                    async.mapLimit publications, 5, @_fillConcept, (err, results) =>
                        if err
                            return callback err
                        return callback null, results


    build: (indexationFilePath, callback) =>
        fs.writeFileSync indexationFilePath,  '', 'utf-8'
        @all (err, publications) =>
            if err
                return callback err
            for pub in publications
                pubId = pub['@id'].split('/')[-1..][0]
                jsonPublication = JSON.stringify {
                    id: pubId
                    title: pub['http://purl.org/dc/elements/1.1/title'][0]
                    # conceptIds: pub['http://kalitmo.org/property/mesh_concept'] # old obirs
                    conceptIds: ("http://obirs/#{cid}" for cid in pub['http://kalitmo.org/property/mesh_concept']) # new obirs
                    href: "http://www.ncbi.nlm.nih.gov/pubmed/#{pubId}"
                }
                fs.appendFileSync indexationFilePath, jsonPublication+'\n', 'utf-8'
            return callback null, 'done'


if require.main is module
    config = require './config.json'

    IndexationBuilder = new IndexationBuilder
    IndexationBuilder.build config.indexationFilePath, (err, data) ->
        if err
            throw err
        console.log data