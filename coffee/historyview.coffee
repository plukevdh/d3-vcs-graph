define ['d3'], ->
  "use strict";

  # Issues: Required that commit data be in sorted order.

  REG_MARKER_END = "url(#triangle)"
  MERGE_MARKER_END = "url(#brown-triangle)"
  FADED_MARKER_END = "url(#faded-triangle)"

  preventOverlap = (commit, view) ->
    commitData = view.commitData
    baseLine = view.baseLine
    shift = view.commitRadius * 4.5
    overlapped = null
    i = 0

    while i < commitData.length
      c = commitData[i]
      if c.cx is commit.cx and c.cy is commit.cy and c isnt commit
        overlapped = c
        break
      i++
    if overlapped
      oParent = view.getCommit(overlapped.parent)
      parent = view.getCommit(commit.parent)
      if overlapped.cy < baseLine
        overlapped = (if oParent.cy < parent.cy then overlapped else commit)
        overlapped.cy -= shift
      else
        overlapped = (if oParent.cy > parent.cy then overlapped else commit)
        overlapped.cy += shift
      preventOverlap overlapped, view

  applyBranchlessClass = (selection) ->
    return  if selection.empty()
    selection.classed "branchless", (d) ->
      d.branchless

    if selection.classed("commit-pointer")
      selection.attr "marker-end", (d) ->
        (if d.branchless then FADED_MARKER_END else REG_MARKER_END)

    else if selection.classed("merge-pointer")
      selection.attr "marker-end", (d) ->
        (if d.branchless then FADED_MARKER_END else MERGE_MARKER_END)


  cx = (commit, view) ->
    parent = view.getCommit(commit.parent)
    parentCX = parent.cx
    if typeof commit.parent2 is "string"
      parent2 = view.getCommit(commit.parent2)
      parentCX = (if parent.cx > parent2.cx then parent.cx else parent2.cx)
    parentCX + (view.commitRadius * 4.5)

  cy = (commit, view) ->
    parent = view.getCommit(commit.parent)
    parentCY = parent.cy
    baseLine = view.baseLine
    shift = view.commitRadius * 4.5
    branches = []
    branchIndex = 0
    i = 0

    while i < view.commitData.length
      d = view.commitData[i]
      branches.push d.id  if d.parent is commit.parent
      i++
    branchIndex = branches.indexOf(commit.id)
    if parentCY is baseLine
      direction = 1
      bi = 0

      while bi < branchIndex
        direction *= -1
        bi++
      shift *= Math.ceil(branchIndex / 2)
      return parentCY + (shift * direction)
    if parentCY < baseLine
      parentCY - (shift * branchIndex)
    else parentCY + (shift * branchIndex)  if parentCY > baseLine

  fixCirclePosition = (selection) ->
    selection.attr("cx", (d) ->
      d.cx
    ).attr "cy", (d) ->
      d.cy


  # calculates the x1 point for commit pointer lines
  px1 = (commit, view, pp) ->
    pp = pp or "parent"
    parent = view.getCommit(commit[pp])
    startCX = commit.cx
    diffX = startCX - parent.cx
    diffY = parent.cy - commit.cy
    length = Math.sqrt((diffX * diffX) + (diffY * diffY))
    startCX - (view.pointerMargin * (diffX / length))

  # calculates the y1 point for commit pointer lines
  py1 = (commit, view, pp) ->
    pp = pp or "parent"
    parent = view.getCommit(commit[pp])
    startCY = commit.cy
    diffX = commit.cx - parent.cx
    diffY = parent.cy - startCY
    length = Math.sqrt((diffX * diffX) + (diffY * diffY))
    startCY + (view.pointerMargin * (diffY / length))

  fixPointerStartPosition = (selection, view) ->
    selection.attr("x1", (d) ->
      px1 d, view
    ).attr "y1", (d) ->
      py1 d, view

  px2 = (commit, view, pp) ->
    pp = pp or "parent"
    parent = view.getCommit(commit[pp])
    endCX = parent.cx
    diffX = commit.cx - endCX
    diffY = parent.cy - commit.cy
    length = Math.sqrt((diffX * diffX) + (diffY * diffY))
    endCX + (view.pointerMargin * 1.2 * (diffX / length))

  py2 = (commit, view, pp) ->
    pp = pp or "parent"
    parent = view.getCommit(commit[pp])
    endCY = parent.cy
    diffX = commit.cx - parent.cx
    diffY = endCY - commit.cy
    length = Math.sqrt((diffX * diffX) + (diffY * diffY))
    endCY - (view.pointerMargin * 1.2 * (diffY / length))

  fixPointerEndPosition = (selection, view) ->
    selection.attr("x2", (d) ->
      px2 d, view
    ).attr "y2", (d) ->
      py2 d, view


  fixIdPosition = (selection, view) ->
    selection.attr("x", (d) ->
      d.cx
    ).attr "y", (d) ->
      d.cy + view.commitRadius + 14


  tagY = tagY = (t, view) ->
    commit = view.getCommit(t.commit)
    commitCY = commit.cy
    tags = commit.tags
    tagIndex = tags.indexOf(t.name)
    tagIndex = tags.length  if tagIndex is -1
    if commitCY < (view.baseLine)
      commitCY - 45 - (tagIndex * 25)
    else
      commitCY + 40 + (tagIndex * 25)

  class HistoryView
    constructor: (config) ->
      @commitData = config.commitData or []
      commit = undefined
      i = 0

      while i < @commitData.length
        commit = @commitData[i]
        not commit.parent and (commit.parent = "initial")
        not commit.tags and (commit.tags = [])
        i++

      @name = config.name or "UnnamedHistoryView"
      @branches = []
      @currentBranch = config.currentBranch or "master"
      @width = config.width or (@commitData.length * 54)
      @height = config.height or 400
      @baseLine = @height * (config.baseLine or 0.6)
      @commitRadius = config.commitRadius or 12
      @pointerMargin = @commitRadius * 1.3
      @initialCommit =
        id: "initial"
        parent: null
        cx: -(@commitRadius * 2)
        cy: @baseLine


    getCommit: getCommit = (ref) ->
      headMatcher = /HEAD(\^+)/.exec(ref)
      matchedCommit = null
      return @initialCommit  if ref is "initial"
      ref = "HEAD"  if headMatcher
      i = 0

      while i < @commitData.length
        commit = @commitData[i]
        if commit is ref
          matchedCommit = commit
          break
        if commit.id is ref
          matchedCommit = commit
          break
        if commit.tags.indexOf(ref) >= 0
          matchedCommit = commit
          break
        i++
      if headMatcher and matchedCommit
        h = 0

        while h < headMatcher[1].length
          matchedCommit = getCommit.call(this, matchedCommit.parent)
          h++
      matchedCommit


    ###
    @method getCircle
    @param ref {String} the id or a tag name that refers to the commit
    @return {d3 Selection} the d3 selected SVG circle
    ###
    getCircle: (ref) ->
      circle = @svg.select("#" + @name + "-" + ref)
      commit = undefined
      return circle  if circle and not circle.empty()
      commit = @getCommit(ref)
      return null  unless commit
      @svg.select "#" + @name + "-" + commit.id

    getCircles: ->
      @svg.selectAll "circle.commit"


    ###
    @method render
    @param container {String} selector for the container to render the SVG into
    ###
    render: (container) ->
      svgContainer = container.append("div").classed("svg-container", true).classed("remote-container", @isRemote)
      svg = svgContainer.append("svg:svg")
      svg.attr("id", @name).attr("width", @width).attr "height", @height
      if @isRemote
        svg.append("svg:text").classed("remote-name-display", true).text(@remoteName).attr("x", 10).attr "y", 25
      else
        svg.append("svg:text").classed("remote-name-display", true).text("Local Repository").attr("x", 10).attr "y", 25
        svg.append("svg:text").classed("current-branch-display", true).attr("x", 10).attr "y", 45
      @svgContainer = svgContainer
      @svg = svg
      @arrowBox = svg.append("svg:g").classed("pointers", true)
      @commitBox = svg.append("svg:g").classed("commits", true)
      @tagBox = svg.append("svg:g").classed("tags", true)
      @renderCommits()
      @_setCurrentBranch @currentBranch

    destroy: ->
      @svg.remove()
      @svgContainer.remove()
      for prop of this
        this[prop] = null  if @hasOwnProperty(prop)

    _calculatePositionData: ->
      i = 0

      while i < @commitData.length
        commit = @commitData[i]
        commit.cx = cx(commit, this)
        commit.cy = cy(commit, this)
        preventOverlap commit, this
        i++

    renderCommits: ->
      @_calculatePositionData()
      @_renderCircles()
      @_renderTooltips()
      @_renderPointers()
      @_renderMergePointers()
      @_renderIdLabels()
      # @checkout @currentBranch

    _renderCircles: ->
      view = this
      existingCircles = @commitBox.selectAll("circle.commit").data(@commitData, (d) ->
        d.id
      ).attr("id", (d) ->
        view.name + "-" + d.id
      ).classed("reverted", (d) ->
        d.reverted
      ).classed("rebased", (d) ->
        d.rebased
      )
      existingCircles.transition().duration(500).call fixCirclePosition
      newCircles = existingCircles.enter().append("svg:circle").attr("id", (d) ->
        view.name + "-" + d.id
      ).classed("commit", true).classed("merge-commit", (d) ->
        typeof d.parent2 is "string"
      ).call(fixCirclePosition).attr("r", 1).transition().duration(500).attr("r", @commitRadius)

    _renderTooltips: ->
      view = this
      circles = @commitBox.selectAll("circle.commit").data(@commitData, (d) -> d.id).each (d) ->
              $(this).tipsy
                  title: ->
                      "#{d.committer} - #{d.comment}"
                  gravity: 's'
                  offset: {height: 0, width: view.commitRadius}

    _renderPointers: ->
      view = this
      existingPointers = @arrowBox.selectAll("line.commit-pointer").data(@commitData, (d) ->
        d.id
      ).attr("id", (d) ->
        view.name + "-" + d.id + "-to-" + d.parent
      )
      existingPointers.transition().duration(500).call(fixPointerStartPosition, view).call fixPointerEndPosition, view
      newPointers = existingPointers.enter().append("svg:line").attr("id", (d) ->
        view.name + "-" + d.id + "-to-" + d.parent
      ).classed("commit-pointer", true).call(fixPointerStartPosition, view).attr("x2", ->
        d3.select(this).attr "x1"
      ).attr("y2", ->
        d3.select(this).attr "y1"
      ).attr("marker-end", REG_MARKER_END).transition().duration(500).call(fixPointerEndPosition, view)

    _renderMergePointers: ->
      view = this
      mergeCommits = []
      i = 0

      while i < @commitData.length
        commit = @commitData[i]
        mergeCommits.push commit  if typeof commit.parent2 is "string"
        i++
      existingPointers = @arrowBox.selectAll("polyline.merge-pointer").data(mergeCommits, (d) ->
        d.id
      ).attr("id", (d) ->
        view.name + "-" + d.id + "-to-" + d.parent2
      )
      existingPointers.transition().duration(500).attr "points", (d) ->
        p1 = px1(d, view, "parent2") + "," + py1(d, view, "parent2")
        p2 = px2(d, view, "parent2") + "," + py2(d, view, "parent2")
        [p1, p2].join " "

      newPointers = existingPointers.enter().append("svg:polyline").attr("id", (d) ->
        view.name + "-" + d.id + "-to-" + d.parent2
      ).classed("merge-pointer", true).attr("points", (d) ->
        x1 = px1(d, view, "parent2")
        y1 = py1(d, view, "parent2")
        p1 = x1 + "," + y1
        [p1, p1].join " "
      ).attr("marker-end", MERGE_MARKER_END).transition().duration(500).attr("points", (d) ->
        points = d3.select(this).attr("points").split(" ")
        x2 = px2(d, view, "parent2")
        y2 = py2(d, view, "parent2")
        points[1] = x2 + "," + y2
        points.join " "
      )

    _renderIdLabels: ->
      view = this
      existingLabels = @commitBox.selectAll("text.id-label").data(@commitData, (d) ->
        d.id
      ).text((d) ->
        d.id
      )
      existingLabels.transition().call fixIdPosition, view
      newLabels = existingLabels.enter().insert("svg:text", ":first-child").classed("id-label", true).text((d) ->
        d.id
      ).call(fixIdPosition, view)

    _parseTagData: ->
      tagData = []
      headCommit = null
      i = 0
      while i < @commitData.length
        c = @commitData[i]
        t = 0

        while t < c.tags.length
          tagName = c.tags[t]
          if tagName.toUpperCase() is "HEAD"
            headCommit = c
          else @branches.push tagName  if @branches.indexOf(tagName) is -1
          tagData.push
            name: tagName
            commit: c.id

          t++
        i++
      unless headCommit
        headCommit = @getCommit(@currentBranch)
        headCommit.tags.push "HEAD"
        tagData.push
          name: "HEAD"
          commit: headCommit.id


      # find out which commits are not branchless
      tagData

    _markBranchlessCommits: ->
      # first mark every commit as branchless
      c = 0
      while c < @commitData.length
        @commitData[c].branchless = true
        c++
      b = 0
      while b < @branches.length
        branch = @branches[b]
        if branch.indexOf("/") is -1
          commit = @getCommit(branch)
          parent = @getCommit(commit.parent)
          parent2 = @getCommit(commit.parent2)
          commit.branchless = false
          while parent
            parent.branchless = false
            parent = @getCommit(parent.parent)

          # just in case this is a merge commit
          while parent2
            parent2.branchless = false
            parent2 = @getCommit(parent2.parent)
        b++
      @svg.selectAll("circle.commit").call applyBranchlessClass
      @svg.selectAll("line.commit-pointer").call applyBranchlessClass
      @svg.selectAll("polyline.merge-pointer").call applyBranchlessClass

    renderTags: ->
      view = this
      tagData = @_parseTagData()
      existingTags = @tagBox.selectAll("g.branch-tag").data(tagData, (d) ->
        d.name
      )
      existingTags.exit().remove()
      existingTags.select("rect").transition().duration(500).attr("y", (d) ->
        tagY d, view
      ).attr "x", (d) ->
        commit = view.getCommit(d.commit)
        width = Number(d3.select(this).attr("width"))
        commit.cx - (width / 2)

      existingTags.select("text").transition().duration(500).attr("y", (d) ->
        tagY(d, view) + 14
      ).attr "x", (d) ->
        commit = view.getCommit(d.commit)
        commit.cx

      newTags = existingTags.enter().append("g").attr("class", (d) ->
        classes = "branch-tag"
        if d.name.indexOf("/") >= 0
          classes += " remote-branch"
        else classes += " head-tag"  if d.name.toUpperCase() is "HEAD"
        classes
      )
      newTags.append("svg:rect").attr("width", (d) ->
        (d.name.length * 6) + 10
      ).attr("height", 20).attr("y", (d) ->
        tagY d, view
      ).attr "x", (d) ->
        commit = view.getCommit(d.commit)
        width = Number(d3.select(this).attr("width"))
        commit.cx - (width / 2)

      newTags.append("svg:text").text((d) ->
        d.name
      ).attr("y", (d) ->
        tagY(d, view) + 14
      ).attr "x", (d) ->
        commit = view.getCommit(d.commit)
        commit.cx

      @_markBranchlessCommits()

    ###
    @method isAncestor
    @param ref1
    @param ref2
    @return {Boolean} whether or not ref1 is an ancestor of ref2
    ###
    isAncestor: isAncestor = (ref1, ref2) ->
      currentCommit = @getCommit(ref1)
      targetTree = @getCommit(ref2)
      inTree = false
      additionalTrees = []
      return false  unless currentCommit
      while targetTree
        if targetTree.id is currentCommit.id
          inTree = true
          targetTree = null
        else
          additionalTrees.push targetTree.parent2  if targetTree.parent2
          targetTree = @getCommit(targetTree.parent)
      return true  if inTree
      i = 0

      while i < additionalTrees.length
        inTree = isAncestor.call(this, currentCommit, additionalTrees[i])
        break  if inTree
        i++
      inTree

  HistoryView = HistoryView
