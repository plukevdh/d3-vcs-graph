define ["d3"], ->
  ###
  @class ControlBox
  @constructor
  ###
  ControlBox = (config) ->
    @historyView = config.historyView
    @originView = config.originView
    @initialMessage = config.initialMessage or "Enter git commands below."
    @_commandHistory = []
    @_currentCommand = -1
    @_tempCommand = ""
    @rebaseConfig = {} # to configure branches for rebase
  "use strict"
  ControlBox:: =
    render: (container) ->
      cBox = this
      cBoxContainer = container.append("div").classed("control-box", true)
      cBoxContainer.style "height", @historyView.height + 5 + "px"
      log = cBoxContainer.append("div").classed("log", true).style("height", @historyView.height - 20 + "px")
      input = cBoxContainer.append("input").attr("type", "text").attr("placeholder", "enter git command")
      input.on "keyup", ->
        e = d3.event
        switch e.keyCode
          when 13
            break  if @value.trim() is ""
            cBox._commandHistory.unshift @value
            cBox._tempCommand = ""
            cBox._currentCommand = -1
            cBox.command @value
            @value = ""
            e.stopImmediatePropagation()
          when 38
            previousCommand = cBox._commandHistory[cBox._currentCommand + 1]
            cBox._tempCommand = @value  if cBox._currentCommand is -1
            if typeof previousCommand is "string"
              cBox._currentCommand += 1
              @value = previousCommand
              @value = @value # set cursor to end
            e.stopImmediatePropagation()
          when 40
            nextCommand = cBox._commandHistory[cBox._currentCommand - 1]
            if typeof nextCommand is "string"
              cBox._currentCommand -= 1
              @value = nextCommand
              @value = @value # set cursor to end
            else
              cBox._currentCommand = -1
              @value = cBox._tempCommand
              @value = @value # set cursor to end
            e.stopImmediatePropagation()

      @container = cBoxContainer
      @log = log
      @input = input
      @info @initialMessage

    destroy: ->
      @log.remove()
      @input.remove()
      @container.remove()
      for prop of this
        this[prop] = null  if @hasOwnProperty(prop)

    _scrollToBottom: ->
      log = @log.node()
      log.scrollTop = log.scrollHeight

    command: (entry) ->
      return  if entry.trim is ""
      split = entry.split(" ")
      @log.append("div").classed("command-entry", true).html entry
      @_scrollToBottom()
      return @error()  if split[0] isnt "git"
      method = split[1]
      args = split.slice(2)
      try
        if typeof this[method] is "function"
          this[method] args
        else
          @error()
      catch ex
        msg = (if (ex and ex.message) then ex.message else null)
        @error msg

    info: (msg) ->
      @log.append("div").classed("info", true).html msg
      @_scrollToBottom()

    error: (msg) ->
      msg = msg or "I don't understand that."
      @log.append("div").classed("error", true).html msg
      @_scrollToBottom()

    commit: ->
      @historyView.commit()

    branch: (args) ->
      if args.length < 1
        @info "You need to give a branch name. " + "Normally if you don't give a name, " + "this command will list your local branches on the screen."
        return
      while args.length > 0
        arg = args.shift()
        switch arg
          when "--remote"
            @info "This command normally displays all of your remote tracking branches."
            args.length = 0
          when "-d"
            name = args.pop()
            @historyView.deleteBranch name
          else
            remainingArgs = [arg].concat(args)
            args.length = 0
            @historyView.branch remainingArgs.join(" ")

    checkout: (args) ->
      while args.length > 0
        arg = args.shift()
        switch arg
          when "-b"
            name = args[args.length - 1]
            try
              @historyView.branch name
            catch err
              throw new Error(err.message)  if err.message.indexOf("already exists") is -1
          else
            remainingArgs = [arg].concat(args)
            args.length = 0
            @historyView.checkout remainingArgs.join(" ")

    reset: (args) ->
      while args.length > 0
        arg = args.shift()
        switch arg
          when "--soft"
            @info "The \"--soft\" flag works in real git, but " + "I am unable to show you how it works in this demo. " + "So I am just going to show you what \"--hard\" looks like instead."
          when "--mixed"
            @info "The \"--mixed\" flag works in real git, but " + "I am unable to show you how it works in this demo."
          when "--hard"
            @historyView.reset args.join(" ")
            args.length = 0
          else
            remainingArgs = [arg].concat(args)
            args.length = 0
            @info "Assuming \"--hard\"."
            @historyView.reset remainingArgs.join(" ")

    clean: (args) ->
      @info "Deleting all of your untracked files..."

    revert: (args) ->
      @historyView.revert args.shift()

    merge: (args) ->
      ref = args.shift()
      result = @historyView.merge(ref)
      @info "You have performed a fast-forward merge."  if result is "Fast-Forward"

    rebase: (args) ->
      ref = args.shift()
      result = @historyView.rebase(ref)
      @info "Fast-forwarded to " + ref + "."  if result is "Fast-Forward"

    fetch: ->
      throw new Error("There is no remote server to fetch from.")  unless @originView
      origin = @originView
      local = @historyView
      remotePattern = /^origin\/([^\/]+)$/
      rtb = undefined
      isRTB = undefined
      fb = undefined
      fetchBranches = {}
      fetchIds = [] # just to make sure we don't fetch the same commit twice
      fetchCommits = []
      resultMessage = ""

      # determine which branches to fetch
      rtb = 0
      while rtb < local.branches.length
        isRTB = remotePattern.exec(local.branches[rtb])
        fetchBranches[isRTB[1]] = 0  if isRTB
        rtb++

      # determine which commits the local repo is missing from the origin
      for fb of fetchBranches
        if origin.branches.indexOf(fb) > -1
          fetchCommit = origin.getCommit(fb)
          notInLocal = local.getCommit(fetchCommit.id) is null
          while notInLocal
            if fetchIds.indexOf(fetchCommit.id) is -1
              fetchCommits.unshift fetchCommit
              fetchIds.unshift fetchCommit.id
            fetchBranches[fb] += 1
            fetchCommit = origin.getCommit(fetchCommit.parent)
            notInLocal = local.getCommit(fetchCommit.id) is null

      # add the fetched commits to the local commit data
      fc = 0

      while fc < fetchCommits.length
        fetchCommit = fetchCommits[fc]
        local.commitData.push
          id: fetchCommit.id
          parent: fetchCommit.parent
          tags: []

        fc++

      # update the remote tracking branch tag locations
      for fb of fetchBranches
        if origin.branches.indexOf(fb) > -1
          remoteLoc = origin.getCommit(fb).id
          local.moveTag "origin/" + fb, remoteLoc
        resultMessage += "Fetched " + fetchBranches[fb] + " commits on " + fb + ".</br>"
      @info resultMessage
      local.renderCommits()

    pull: (args) ->
      control = this
      local = @historyView
      currentBranch = local.currentBranch
      rtBranch = "origin/" + currentBranch
      isFastForward = false
      @fetch()
      throw new Error("You are not currently on a branch.")  unless currentBranch
      throw new Error("Current branch is not set up for pulling.")  if local.branches.indexOf(rtBranch) is -1
      setTimeout (->
        try
          if args[0] is "--rebase" or control.rebaseConfig[currentBranch] is "true"
            isFastForward = local.rebase(rtBranch) is "Fast-Forward"
          else
            isFastForward = local.merge(rtBranch) is "Fast-Forward"
        catch error
          control.error error.message
        control.info "Fast-forwarded to " + rtBranch + "."  if isFastForward
      ), 750

    push: (args) ->
      control = this
      local = @historyView
      remoteName = args.shift() or "origin"
      remote = this[remoteName + "View"]
      branchArgs = args.pop()
      localRef = local.currentBranch
      remoteRef = local.currentBranch
      localCommit = undefined
      remoteCommit = undefined
      findCommitsToPush = undefined
      isCommonCommit = undefined
      toPush = []
      throw new Error("Sorry, you can't have a remote named \"history\" in this example.")  if remoteName is "history"
      throw new Error("There is no remote server named \"" + remoteName + "\".")  unless remote
      if branchArgs
        branchArgs = /^([^:]*)(:?)(.*)$/.exec(branchArgs)
        branchArgs[1] and (localRef = branchArgs[1])
        branchArgs[2] is ":" and (remoteRef = branchArgs[3])
      throw new Error("Local ref: " + localRef + " does not exist.")  if local.branches.indexOf(localRef) is -1
      throw new Error("No remote branch was specified to push to.")  unless remoteRef
      localCommit = local.getCommit(localRef)
      remoteCommit = remote.getCommit(remoteRef)
      findCommitsToPush = findCommitsToPush = (localCommit) ->
        commitToPush = undefined
        isCommonCommit = remote.getCommit(localCommit.id) isnt null
        until isCommonCommit
          commitToPush =
            id: localCommit.id
            parent: localCommit.parent
            tags: []

          if typeof localCommit.parent2 is "string"
            commitToPush.parent2 = localCommit.parent2
            findCommitsToPush local.getCommit(localCommit.parent2)
          toPush.unshift commitToPush
          localCommit = local.getCommit(localCommit.parent)
          isCommonCommit = remote.getCommit(localCommit.id) isnt null


      # push to an existing branch on the remote
      if remoteCommit and remote.branches.indexOf(remoteRef) > -1
        throw new Error("Push rejected. Non fast-forward.")  unless local.isAncestor(remoteCommit.id, localCommit.id)
        isCommonCommit = localCommit.id is remoteCommit.id
        return @info("Everything up-to-date.")  if isCommonCommit
        findCommitsToPush localCommit
        remote.commitData = remote.commitData.concat(toPush)
        remote.moveTag remoteRef, toPush[toPush.length - 1].id
        remote.renderCommits()
      else
        @info "Sorry, creating new remote branches is not supported yet."

    config: (args) ->
      path = args.shift().split(".")
      @rebase[path[1]] = args.pop()  if path[2] is "rebase"  if path[0] is "branch"

  ControlBox
