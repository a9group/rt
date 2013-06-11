function filter_cascade_by_id (id, val, is_hierarchical) {
    var select = document.getElementById(id);
    var complete_select = document.getElementById(id + "-Complete" );
    return filter_cascade(select, complete_select, val, is_hierarchical);
}

function filter_cascade (select, complete_select, val, is_hierarchical) {
    if (!select) { return };
    var i;
    var children = select.childNodes;

    if ( complete_select ) {
        while (select.hasChildNodes()){
            select.removeChild(select.firstChild);
        }

        var complete_children = complete_select.childNodes;

        if ( val == '' && is_hierarchical ) {
            // no category, and the category is from a hierchical cf;
            // leave this set of options empty
        } else if ( val == '' ) {
            // no category, let's clone all node
            for (i in complete_children) {
                if ( complete_children[i].cloneNode ) {
                    new_option = complete_children[i].cloneNode(true);
                    select.appendChild(new_option);
                }
            }
        }
        else {
            for (i in complete_children) {
                if (!complete_children[i].label ||
                      (complete_children[i].hasAttribute &&
                            !complete_children[i].hasAttribute('label') ) ||
                        complete_children[i].label.substr(0, val.length) == val ) {
                    if ( complete_children[i].cloneNode ) {
                        new_option = complete_children[i].cloneNode(true);
                        select.appendChild(new_option);
                    }
                }
            }
        }
    }
    else {
// for back compatibility
        for (i in children) {
            if (!children[i].label) { continue };
            if ( val == '' && is_hierarchical ) {
                hide(children[i]);
                continue;
            }
            if ( val == '' || children[i].label.substr(0, val.length) == val) {
                show(children[i]);
                continue;
            }
            hide(children[i]);
        }
    }
}
