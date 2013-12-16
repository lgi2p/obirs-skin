
window.Obirs or= {}

app = window.Obirs

###
*
* Handlebars helpers
*
###

handlebarsHelpers =
    'percent': (input) ->
        parseInt(parseFloat(input).toFixed(5) * 100)

    'lowercase': (input) ->
        input.toLowerCase()

for helperName, helper of handlebarsHelpers
    Handlebars.registerHelper helperName, helper


###
*
* Utils
*
###

class app.LoadingView

    constructor: () ->
        @_inderval = null
        @message = 'Please wait a few seconds while we are getting your results...'
        @pendingMessage = "Please wait ${waitingTime} seconds while we are getting your results..."
        @endMessage = 'Almost there, wait for it..!'

    show: (msg, waitingTime) ->
        message = msg or @message
        $.mobile.loading "show", {
            text: message
            textVisible: "true"
            theme: "a"
        }
        if waitingTime
            @_interval = setInterval ()=>
                if waitingTime <= 0
                    text = @endMessage
                else
                    text = @pendingMessage.replace('${waitingTime}', waitingTime)
                $(".ui-loader h1").text(text)
                waitingTime -= 1
            , 1000

    hide: () ->
        $.mobile.loading("hide")
        clearInterval(@_interval)
        @_interval = null

app.loading = new app.LoadingView()


###
*
* Models & Collections
*
###

class app.QueryConcept extends Backbone.Model

    urlRoot: '/api/concepts'

    defaults: {
        id: null
        title: ""
        weight: null
    }
        
    fetchTitle: () ->
        $.get("#{@urlRoot}/#{@id}").success (data) =>
            @.set 'title', data.results.title



class app.QueryConcepts extends Backbone.Collection

    model: app.QueryConcept

    # Normalize the weight of each concept so their sum would be equal to 1
    normalizeWeight: () ->
        totalWeight = 0
        for weight in  @.pluck('weight')
            totalWeight += weight
        for concept in @.models
            concept.set 'weight', concept.get('weight')/totalWeight, {silent: true}
        concept.trigger('change')
    
    removeConceptId: (conceptId) ->
        concept = @findWhere({id: conceptId})
        @remove(concept)
        @trigger 'updateUrl'



class app.Results extends Backbone.Collection

    initialize: () ->
        @listenTo @, 'reset', @updateChartUrl

    updateChartUrl: () ->
        size = 150
        relationTypeColorMapping = {
            "EXACT": "27AE60", # "007F00", //"8CFF8E",
            "ASC":  "2980B9",  # "0000FD", //"FFC88C",
            "DESC":  "C0392B", # "FD0000", //"FF8cCFD",
            "OTHER": "8E44AD"  # "A800FD", //"8CC4FF"
        }
        srcUrl = "https://chart.googleapis.com/chart?cht=bvs&chs=#{size}x#{size}&chbh=a&chxt=x,y"

        for publication in @.models
            labels = '&chxl=0:'
            scores = []
            colorations = []
            for concept, index in publication.get('concepts')
                labels += "|#{index}"
                scores.push concept.score * 100
                colorations.push relationTypeColorMapping[concept.relationType]
            url = srcUrl + labels
            if scores.length
                url += "&chd=t:#{scores.join(',')}"
            if colorations.length
                url += "&chco=#{colorations.join('|')}"
            publication.set('chartUrl', url, {silent: true})



class app.MoreLikeIt extends Backbone.Collection



class app.AppControl extends Backbone.Model

    defaults: {
        advancedCtrl: false
    }

    initialize: () ->
        @queryConcepts = new app.QueryConcepts()
        @results = new app.Results()
        @moreLikeIt = new app.MoreLikeIt()
        @listenTo @queryConcepts, 'updateUrl', @updateUrl


    updateUrl: () ->
        query = []
        for cpt in @queryConcepts.toJSON()
            weight = parseFloat(cpt.weight).toFixed(2)
            query.push "#{cpt.id}:#{weight}"
        query = query.join(',')
        url = "##{query}"
        if @get('aggregatorParameter')
            url += "&q=#{@get('aggregatorParameter')}"
        Backbone.history.navigate(url)

    search: () ->
        app.loading.show(null, @queryConcepts.size())
        @queryConcepts.normalizeWeight()
        query = @queryConcepts.map (concept) -> {id: concept.id, weight: concept.get('weight')}
        $.ajax({
            url: "/api/query"
            data: JSON.stringify({
                concepts: query
                defaultNameSpace: 'http://obirs'
                aggregatorParameter: @get('aggregatorParameter')
            })
            dataType: 'json'
            contentType: 'application/json'
            method: "POST"
        }).success (data) =>
            if not data.results.length
                @results.noResults = true
            else
                @results.noResults = false
            @results.reset data.results
            app.loading.hide()


    refine: () ->
        selectedDocs = @moreLikeIt.filter (obj) ->
            obj if obj.get('status') is 1
        rejectedDocs = @moreLikeIt.filter (obj) ->
            obj if obj.get('status') is 2
        @queryConcepts.normalizeWeight()
        query = {
            selectedDocIds: _.pluck(selectedDocs, 'id')
            rejectedDocIds: _.pluck(rejectedDocs, 'id')
            query: {
                concepts: @queryConcepts.map (concept) -> {id: concept.id, weight: concept.get('weight')}
                defaultNameSpace: 'http://obirs'
            }
        }
        app.loading.show('Please, wait while we are refining your query...')
        $.ajax({
            url: "/api/query/refine"
            data: JSON.stringify(query)
            dataType: 'json'
            contentType: 'application/json'
            method: "POST"
        }).success (data) =>
            concepts = []
            for item in data.results?.concepts
                concept = {}
                concept.id = item.id.split('/')[-1..][0]
                concept.weight = item.weight
                concept.title = item.title
                concepts.push concept
            @queryConcepts.reset(concepts)
            @queryConcepts.trigger 'updateUrl'
            @moreLikeIt.reset()
            @results.reset()
            app.loading.hide()


###
*
* Views
*
###

###
*
* The autocomple input field.
* @collection: QueryConcepts
*
###

class app.ConceptAutocompleteView extends Backbone.View

    el: '#concept-autocomplete'

    initialize: ()->
        that = @
        @$('input.autocomplete-input').autocomplete {
            target: @$(".autocomplete-suggestions")
            source: "/api/search/concepts"
            minLength: 1
            icon: 'add'
            onNoResults: () ->
                that.$(".ui-input-search.ui-focus").addClass("search-no-results")
            onLoading: () ->
                that.$(".ui-input-search.ui-focus").removeClass("search-no-results")
            dataHandler: (data) ->
                # fetch the data from the server in order to display it
                res = []
                for obj in data.results or []
                    res.push {'label': obj.title, 'value': obj.id}
                return res
            callback: (e) ->
                ###
                *
                * Action called when a concept is selected. It parse the selected
                * concept, add it to the queryConcepts collection, clear 
                * suggestion and remove the input
                *
                ###
                obj = JSON.parse(e.target.dataset.autocomplete)
                obj.weight = 1.0
                obj.title = obj.label
                obj.id = obj.value
                delete obj.label
                delete obj.value
                that.collection.add obj
                @.target.html(""); # clear suggestions
                that.$("input.autocomplete-input").val("");
                that.collection.trigger 'updateUrl'
        }

###
*
* The query view contains all the concepts of the query
* @model: AppControl
*
###

class app.QueryView extends Backbone.View



    el: '#queryConcept'

    template: Handlebars.compile """
        <div class="ui-grid-b ui-responsive" >
            <div class="ui-block-a">
                {{#each concepts}}
                    <span>
                        <a href="#" data-action="removeconcept" data-conceptId="{{id}}" data-mini="true" data-inline="true" data-role="button" data-icon="delete" data-iconpos="right">
                            {{title}}
                        </a>
                    </span>
                {{else}}
                    <i>No concept selected yet</i>
                {{/each}}
            </div>
            
            <div class="ui-block-b search-cmd">
                <a href="#" data-role="button" data-mini="true" data-action="search" class="search-btn" data-theme="e" data-icon="search" data-inline="true">search</a>
            </div>
            <div class="ui-block-c search-cmd">
                <label for="toggle-advanced-search" class="ui-hidden-accessible">Toggle simple/advanced search</label>
                <select class="advanced-switch" name="toggle-advanced-search" data-role="slider" data-mini="true">
                    <option {{^advancedCtrl}}selected="selected"{{/advancedCtrl}} value="simple">simple</option>
                    <option {{#advancedCtrl}}selected="selected"{{/advancedCtrl}}value="advanced">advanced</option>
                </select>
            </div>
        </div>

        <div>
            <fieldset class="advanced-search {{^advancedCtrl}}hidden{{/advancedCtrl}}" data-role="fieldcontain">
                <h3>Advanced search</h3>
                <div data-role="fieldcontain">
                    {{#each concepts}}
                        <label for="refine-{{id}}">{{title}}</label>
                        <input class="refine-concept-slider" data-popup-enabled="true" type="range" data-conceptid="{{id}}" data-highlight="true"  data-mini="true"  name="refine-{{id}}" id="refine-{{id}}" min="0" max="1" step="0.01" value="{{weight}}" />
                    {{/each}}
                </div>
                <!--
                <a href="#" class="show-expert-btn muted"><small>show expert section</small></a>
                <div class="expert-section hidden">
                    <div data-role="fieldcontain">
                        <label for="aggregatorParameter">aggregator parameter</label>
                        <input type="number" name="number" min="-50" max="50" name="aggregatorParameter" data-mini="true" id="aggregatorParameter" value="{{aggregatorParameter}}" />
                    </div>
                </div>
                -->
            </fielset>
        </div>
    """

    events: {
        'change .advanced-switch': 'switchAdvancedControl'
        'change .refine-concept-slider': 'changeWeight'
        'click [data-action=removeconcept]': 'removeConcept'
        'click [data-action=search]': 'search'
    }

    initialize: () ->
        @listenTo @model.queryConcepts, 'all', @render
        @listenTo @model.queryConcepts, 'all', @clearResults


    render: () ->
        @$el.html @template {
            concepts: @model.queryConcepts.toJSON()
            advancedCtrl: @model.get('advancedCtrl')
        }
        @$el.trigger('create') # trigger the jquery mobile element
        @

    switchAdvancedControl: (ev) ->
        ev.preventDefault()
        @$(".advanced-search").toggle()
        @model.set 'advancedCtrl', !@model.get('advancedCtrl')

    changeWeight: (ev) ->
        ev.preventDefault()
        weight = $(ev.currentTarget).val()
        conceptId = ev.currentTarget.dataset.conceptid
        concept = @model.queryConcepts.findWhere {id: conceptId}
        concept.set 'weight', parseFloat(weight), {silent: true}
        @model.queryConcepts.add(concept)

    removeConcept: (ev) ->
        ev.preventDefault()
        conceptId = ev.currentTarget.dataset.conceptid
        @model.queryConcepts.removeConceptId(conceptId)

    search: (ev) ->
        ev.preventDefault()
        @model.search()

    clearResults: () ->
        @model.results.reset()


class app.ResultsView extends Backbone.View

    el: '#results'

    template: Handlebars.compile """
        {{#if results.length}}
            {{#if enableRefine}}
            <div style="float:right;text-align:right">
                <a href="#" id="refine-btn" data-role="button" class="ui-disabled"
                  data-mini="true" data-theme="c" data-icon="forward" data-action="refine">refine</a>
            </div>
            {{/if}}
            <h1 class="heading">Results</h1>
            <ul data-role="listview" class="normal-list" data-inset="true" data-theme="c"
              data-split-icon="plus" data-split-theme="d">
                <li data-role="list-divider" class="divider" data-theme="c">
                    First 30 results:
                </li>
                {{#each results}}
                <li class="resultItem">
                    <a href="{{href}}" target="_blank">
                        {{#if concepts}}
                        <img src="{{{chartUrl}}}"  data-ob-action="show-document" data-ob-docid="{{docId}}" />
                        {{/if}}
                        <h2 class="doc-title">{{docTitle}}</h2>
                        <p>
                            {{#concepts}}
                                <span class="{{lowercase relationType}}-match">
                                    {{matchingConcept.title}}
                                </span>
                                <span class="bull"> &bull;</span>
                            {{/concepts}}
                        </p>
                        <span class="ui-li-count score">{{percent score}}%</span>
                   </a>
                   {{#if concepts}}
                   <a href="#" data-icon="info" data-action="add-more-like-it" class="select-refined"
                     data-docid="{{docId}}">more like it</a>
                    {{/if}}
                </li>
                {{/each}}
            </ul>
        {{/if}}
        {{#if noResults}}
            <p>no results found</p>
        {{/if}}
    """

    # options:
    #   collection: results collection
    #   appModel: application model
    initialize: (options) ->
        @appModel = options.appModel
        @listenTo @collection, 'all', @render

    render: (ev) ->
        results = @collection.toJSON()
        @$el.html @template {
            results: results,
            noResults: @collection.noResults,
            enableRefine: results?[0]?.concepts?}
        @$el.trigger('create')
        @



class app.MoreLikeItView extends Backbone.View

    el: '#results'

    events: {
        'click [data-action=add-more-like-it]': 'toggleMoreLikeIt'
        'click [data-action=refine]': 'refine'
    }

    initialize: () ->
        @collection = @model.moreLikeIt
        @listenTo @collection, 'change', @render
        @listenTo @collection, 'reset', @clear
        @listenTo @model, 'refine:done', @clear

    toggleMoreLikeIt: (ev) ->
        ev.preventDefault()
        docid = ev.currentTarget.dataset.docid
        model = @collection.get(docid)
        if not model
            model = @collection.add {id: docid, status: 0}
        status = (model.get('status') + 1) % 3
        model.set 'status', status

    render: (foo, bar, arf, arg) ->
        for model in @collection.models
            docid = model.get('id')
            status = model.get('status')
            $btn =  @$("[data-action=add-more-like-it][data-docid=#{docid}] span.ui-btn-icon-notext")
            $icon = $btn.find("span span.ui-icon")
            if status is 1
                $btn.addClass("refine-wanted")
                $icon.addClass("ui-icon-plus").removeClass("ui-icon-info")
            else if status is 2
                $btn.addClass("refine-not-wanted").removeClass("refine-wanted")
                $icon.addClass("ui-icon-minus").removeClass("ui-icon-plus")
            else
                $btn.removeClass("refine-not-wanted").removeClass("refine-wanted")
                $icon.removeClass("ui-icon-plus").removeClass("ui-icon-minus").addClass("ui-icon-info")
        if _.compact(@collection.pluck('status')).length
            @enabledRefineBtn()
        else
            @disableRefineBtn()

    enabledRefineBtn: () ->
        @$("#refine-btn").removeClass("ui-disabled").addClass("ui-btn-up-e").removeClass("ui-btn-up-d")


    disableRefineBtn: () ->
        @$("#refine-btn").addClass("ui-disabled").removeClass("ui-btn-up-e").addClass("ui-btn-up-d")        

    # refine the query
    refine: (ev) ->
        ev.preventDefault()
        @model.refine()

    # clear all refine selected buttons
    clear: () ->
        $btns = @$('.select-refined')
        $icons = $btns.find('span.ui-icon')
        @$('.select-refined .refine-wanted').removeClass('refine-wanted')
        @$('.select-refined .refine-not-wanted').removeClass('refine-not-wanted')
        $icons.removeClass("ui-icon-plus").removeClass("ui-icon-minus").addClass("ui-icon-info")
        @disableRefineBtn()



class app.AppView extends Backbone.View

    el: '#layout'

    initialize: () ->
        new app.QueryView({model: @model})
        new app.ConceptAutocompleteView({collection: @model.queryConcepts})
        new app.ResultsView({collection: @model.results, appModel: @model})
        new app.MoreLikeItView({model: @model})



class app.Router extends Backbone.Router

    routes: {
        ":query&q=:q":        "search"
        ":query":        "search"
    }

    initialize: () ->
        @appControl = new app.AppControl()
        @appView = new app.AppView({model: @appControl})


    search: (query, q) ->
        concepts = []
        for cpt in query.split(',')
            [conceptId, conceptWeight] = cpt.split(':')
            concept = new app.QueryConcept({id: conceptId, weight: parseFloat(conceptWeight)})
            concept.fetchTitle()
            concepts.push concept
        if not q?
            q = 2
        @appControl.set 'aggregatorParameter', q, {silent: true}
        @appControl.queryConcepts.reset concepts

$ ->
    new window.Obirs.Router()
    Backbone.history.start()