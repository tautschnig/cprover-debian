/*
 * The MIT License
 * 
 * Copyright (c) 2012, Jesse Farinacci
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

if (ks_enabled) {
  var ks_previous_code;
  var ks_previous_char;
  var ks_view_job_selected;

  Event.observe(window, 'load', function() {
    Event.observe(document, 'keydown', ks_keydown);
    Event.observe(document, 'keypress', ks_keypress);
  });

  /* JENKINS-13106 - event.stopPropagation() and event.cancelBubble=true both fail */
  function clearSearchBox() {
    Form.Element.clear('search-box');
  }

  /* try to play nicely with forms, so no keyboard shortcuts */
  function ks_in_form() {
    return document.activeElement == null || 'INPUT' == document.activeElement.tagName
        || 'TEXTAREA' == document.activeElement.tagName;
  }

  function ks_get_keycode(event) {
    if (event == null) {
      event = window.event;
    }

    if (event.keyCode) {
      return event.keyCode;
    }

    if (event.which) {
      return event.which;
    }

    return null;
  }

  function ks_keydown(e) {
    /* always hide the shortcuts help, if user hits '?' again, re-display it */
    ks_hide_help();

    // ---

    if (ks_in_form()) {
      return;
    }

    // ---

    var ks_code = ks_get_keycode(e);

    if (ks_code != null) {
      switch (ks_code) {
        case Event.KEY_RETURN:
          if (ks_is_view_selector) {
            ks_view_selector_open();
          }
          else if (ks_is_job_selector) {
            ks_job_selector_open();
          }
          else if (ks_is_node_selector) {
            ks_node_selector_open();
          }
          else if (ks_is_permalink_selector) {
            ks_permalink_selector_open();
          }
          break;

        case Event.KEY_ESC:
          ks_selector_hide();
          break;

        case Event.KEY_LEFT:
        case Event.KEY_UP:
          if (ks_is_view_selector) {
            ks_view_selector_prev();
          }
          else if (ks_is_job_selector) {
            ks_job_selector_prev();
          }
          else if (ks_is_node_selector) {
            ks_node_selector_prev();
          }
          else if (ks_is_permalink_selector) {
            ks_permalink_selector_prev();
          }
          break;

        case Event.KEY_RIGHT:
        case Event.KEY_DOWN:
          if (ks_is_view_selector) {
            ks_view_selector_next();
          }
          else if (ks_is_job_selector) {
            ks_job_selector_next();
          }
          else if (ks_is_node_selector) {
            ks_node_selector_next();
          }
          else if (ks_is_permalink_selector) {
            ks_permalink_selector_next();
          }
          break;

        case Event.KEY_HOME:
        case Event.KEY_PAGEUP:
          if (ks_is_view_selector) {
            ks_view_selector_first();
          }
          else if (ks_is_job_selector) {
            ks_job_selector_first();
          }
          else if (ks_is_node_selector) {
            ks_node_selector_first();
          }
          else if (ks_is_permalink_selector) {
            ks_permalink_selector_first();
          }
          break;

        case Event.KEY_END:
        case Event.KEY_PAGEDOWN:
          if (ks_is_view_selector) {
            ks_view_selector_last();
          }
          else if (ks_is_job_selector) {
            ks_job_selector_last();
          }
          else if (ks_is_node_selector) {
            ks_node_selector_last();
          }
          else if (ks_is_permalink_selector) {
            ks_permalink_selector_last();
          }
          break;

        case Event.KEY_BACKSPACE:
        case Event.KEY_DELETE:
          if (ks_is_selector()) {
            if (!ks_selector_filter.empty()) {
              ks_selector_filter = ks_selector_filter.substring(0, ks_selector_filter.length - 1);

              if (ks_is_view_selector) {
                ks_view_selector_filter();
              }
              else if (ks_is_job_selector) {
                ks_job_selector_filter();
              }
              else if (ks_is_node_selector) {
                ks_node_selector_filter();
              }
              else if (ks_is_permalink_selector) {
                ks_permalink_selector_filter();
              }
            }
          }
          break;
      }
    }
  }

  function ks_keypress(e) {
    /* always hide the shortcuts help, if user hits '?' again, re-display it */
    ks_hide_help();

    // ---

    if (ks_in_form()) {
      return;
    }

    // ---

    var ks_code = ks_get_keycode(e);
    var ks_character = String.fromCharCode(ks_code);

    if (ks_is_selector()) {
      switch (ks_character) {
        case '?':
          ks_show_help();
          break;

        default:
          ks_selector_filter += ks_character.toLowerCase();

          if (ks_is_view_selector) {
            ks_view_selector_filter();
          }
          else if (ks_is_job_selector) {
            ks_job_selector_filter();
          }
          else if (ks_is_node_selector) {
            ks_node_selector_filter();
          }
          else if (ks_is_permalink_selector) {
            ks_permalink_selector_filter();
          }
          break;
      }
    }

    else {
      switch (ks_character) {
        case '?':
          ks_show_help();
          break;

        case '/':
          $('search-box').focus();
          setTimeout("clearSearchBox(/* someone kill me */)", 1);
          break;

        case 'b':
          if (ks_is_job()) {
            ks_set_window_location(ks_url + '/' + ks_url_job + '/build?delay=0sec');
          }
          else if (ks_is_view()) {
            if (typeof ks_view_job_selected != 'undefined') {
              ks_set_window_location(ks_url + '/job/' + ks_view_job_selected + '/build?delay=0sec');
            }
          }
          break;

        case 'c':
          if (ks_previous_character_was_character('g')) {
            if (ks_is_job()) {
              ks_set_window_location(ks_url + '/' + ks_url_job + '/changes');
            }
          }
          break;

        case 'C':
          if (ks_previous_character_was_character('g')) {
            if (ks_is_job()) {
              ks_set_window_location(ks_url + '/' + ks_url_job + '/configure');
            }
            else if (ks_is_view()) {
              ks_set_window_location(ks_url + '/' + ks_url_view + '/configure');
            }
            else {
              ks_set_window_location(ks_url + '/configure');
            }
          }
          break;

        case 'h':
          if (ks_previous_character_was_character('g')) {
            ks_set_window_location(ks_url);
          }
          break;

        case 'H':
          if (ks_previous_character_was_character('g')) {
            if (ks_is_view()) {
              ks_set_window_location(ks_url + '/' + ks_url_view + '/builds');
            }
          }
          break;

        case 'j':
          if (ks_previous_character_was_character('g')) {
            ks_job_selector_show();
          }
          else {
            if (ks_is_view()) {
              ks_view_job_next();
            }
          }
          break;

        case 'k':
          if (ks_is_view()) {
            ks_view_job_prev();
          }
          break;

        case 'm':
          if (ks_previous_character_was_character('g')) {
            if (ks_is_job()) {
              ks_set_window_location(ks_url + '/' + ks_url_job + '/modules');
            }
            else {
              ks_set_window_location(ks_url + '/manage');
            }
          }
          break;

        case 'n':
          if (ks_previous_character_was_character('g')) {
            ks_set_window_location(ks_url + '/computer');
          }
          else {
            if (ks_is_view()) {
              ks_view_job_next();
            }
          }
          break;

        case 'N':
          if (ks_previous_character_was_character('g')) {
            ks_node_selector_show();
          }
          break;

        case 'o':
          if (ks_is_view()) {
            ks_view_job_open();
          }
          break;

        case 'p':
          if (ks_previous_character_was_character('g')) {
            if (ks_is_job()) {
              ks_permalink_selector_show();
            }
            else {
              ks_set_window_location(ks_url + '/people');
            }
          }
          else {
            if (ks_is_view()) {
              ks_view_job_prev();
            }
          }
          break;

        case 'P':
          if (ks_previous_character_was_character('g')) {
            if (ks_is_job()) {
              ks_set_window_location(ks_url + '/' + ks_url_job + '/scmPollLog');
            }
            else {
              ks_set_window_location(ks_url + '/pluginManager');
            }
          }
          break;

        case 'r':
          ks_set_window_location(window.location.href);
          break;

        case 's':
          if (ks_previous_character_was_character('g')) {
            if (ks_is_job()) {
              ks_set_window_location(ks_url + '/' + ks_url_job);
            }
          }
          break;

        case 't':
          if (ks_previous_character_was_character('g')) {
            if (ks_is_job()) {
              ks_set_window_location(ks_url + '/' + ks_url_job + '/buildTimeTrend');
            }
          }
          break;

        case 'v':
          if (ks_previous_character_was_character('g')) {
            ks_view_selector_show();
          }
          break;

        case 'w':
          if (ks_previous_character_was_character('g')) {
            if (ks_is_job()) {
              ks_set_window_location(ks_url + '/' + ks_url_job + '/ws');
            }
          }
          break;

        default:
          // console.debug('code: ' + ks_code + ', character: ' + ks_character);
          break;
      }

      ks_previous_code = ks_code;
      ks_previous_character = String.fromCharCode(ks_code);
    }
  }

  function ks_compact_href(href) {
    return href.strip().gsub('(?!:)//', '/');
  }

  function ks_set_window_location(href) {
    window.location.href = ks_compact_href(href);
  }

  function ks_is_job() {
    return typeof ks_is_job_page != 'undefined' && ks_is_job_page;
  }

  function ks_is_view() {
    return typeof ks_is_view_page != 'undefined' && ks_is_view_page;
  }

  function ks_is_selector() {
    return ks_is_view_selector || ks_is_job_selector || ks_is_node_selector || ks_is_permalink_selector;
  }

  function ks_show_help() {
    ks_selector_hide();
    $('ks-help').show();
  }

  function ks_hide_help() {
    $('ks-help').hide();
  }

  function ks_previous_character_was_character(character) {
    if (typeof ks_previous_character == 'undefined') {
      return false;
    }

    if (typeof character == 'undefined') {
      return false;
    }

    return ks_previous_character == character;
  }

  function ks_view_job_next() {
    ks_hide_help();
    if (typeof ks_view_job_names != 'undefined') {
      if (ks_view_job_names.length > 0) {
        ks_view_job_names.each(function(job) {
          $('job_' + job).removeClassName('ks-view-job-selected');
        });
        var idx = ks_view_job_names.indexOf(ks_view_job_selected) + 1;
        if (idx >= ks_view_job_names.length) {
          idx = 0;
        }
        ks_view_job_selected = ks_view_job_names[idx];
        $('job_' + ks_view_job_selected).addClassName('ks-view-job-selected');
      }
    }
  }

  function ks_view_job_prev() {
    if (typeof ks_view_job_names != 'undefined') {
      if (ks_view_job_names.length > 0) {
        ks_view_job_names.each(function(job) {
          $('job_' + job).removeClassName('ks-view-job-selected');
        });
        var idx = ks_view_job_names.indexOf(ks_view_job_selected) - 1;
        if (idx < 0) {
          idx = ks_view_job_names.length - 1;
        }
        ks_view_job_selected = ks_view_job_names[idx];
        $('job_' + ks_view_job_selected).addClassName('ks-view-job-selected');
      }
    }
  }

  function ks_view_job_open() {
    if (typeof ks_view_job_selected != 'undefined') {
      ks_set_window_location(ks_url + '/' + ks_url_view + '/job/' + ks_view_job_selected);
    }
  }

  function ks_filter_matching(filter, list) {
    return list.findAll(function(o) {
      return o.toLowerCase().indexOf(filter) >= 0;
    });
  }

  function ks_filter_matching_idx(filter, list) {
    return list.findAll(function(o) {
      return $H(o).get('name').toLowerCase().indexOf(filter) >= 0;
    }).map(function(o) {
      return $H(o).get('idx');
    });
  }

  function ks_map_idx(list) {
    return ks_list_hash_map_get(list, 'idx');
  }

  function ks_map_name(list) {
    return ks_list_hash_map_get(list, 'name');
  }

  function ks_list_hash_map_get(list, key) {
    return list.map(function(item) {
      return $H(item).get(key);
    });
  }

  function ks_find_item_by_idx(list, idx) {
    return list.find(function(item) {
      return item != null && $H(item).get('idx') == idx;
    });
  }

  function ks_selector_hide() {
    $('ks-selector').hide();
    $('ks-selector-filter').hide();
    $('ks-view-selector-filter-empty').hide();
    $('ks-job-selector-filter-empty').hide();
    $('ks-node-selector-filter-empty').hide();
    $('ks-permalink-selector-filter-empty').hide();

    ks_is_view_selector = false;
    ks_is_job_selector = false;
    ks_is_node_selector = false;
    ks_is_permalink_selector = false;

    ks_selector_filter = '';
  }

  // ----------------------------------------------------------------------- //
  // ----------------------------------------------------------------------- //

  /*
   * View Selector stuff
   */

  var ks_view_selector_input;
  var ks_view_selector_selected;

  function ks_view_selector_select(view) {
    if (ks_is_view_selector) {
      ks_map_idx(ks_views).each(function(v) {
        $(v).removeClassName('ks-selector-selected');
      });

      if (typeof view != 'undefined') {
        ks_view_selector_selected = view;
        $(view).addClassName('ks-selector-selected');
        $('ks-selector-items-empty').hide();
      }
      else {
        $('ks-selector-items-empty').show();
      }
    }
  }

  function ks_view_selector_first() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_views);
    ks_view_selector_select(ks_matching[0]);
  }

  function ks_view_selector_last() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_views);
    ks_view_selector_select(ks_matching[ks_matching.length - 1]);
  }

  function ks_view_selector_next() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_views);
    var idx = ks_matching.indexOf(ks_view_selector_selected) + 1;
    if (idx >= ks_matching.length) {
      idx = 0;
    }

    ks_view_selector_select(ks_matching[idx]);
  }

  function ks_view_selector_open() {
    if (typeof ks_view_selector_selected != 'undefined') {
      ks_selector_hide();
      var item = ks_find_item_by_idx(ks_views, ks_view_selector_selected);
      if (item != null) {
        ks_set_window_location(ks_url + $H(item).get('url'));
      }
    }
  }

  function ks_view_selector_prev() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_views);
    var idx = ks_matching.indexOf(ks_view_selector_selected) - 1;
    if (idx < 0) {
      idx = ks_matching.length - 1;
    }

    ks_view_selector_select(ks_matching[idx]);
  }

  function ks_view_selector_show() {
    $('ks-selector').show();
    $('ks-view-selector-filter-empty').show();

    if (typeof ks_views != 'undefined') {
      $('ks-selector-items').innerHTML = ks_views.map(function(view) {
        return '<li id="#{idx}">#{name}</li>'.interpolate($H(view));
      }).join('');
    }

    ks_is_view_selector = true;
    ks_view_selector_first();
  }

  function ks_view_selector_filter() {
    if (ks_is_view_selector) {
      $('ks-selector-filter').innerText = ks_selector_filter;

      if (ks_selector_filter.empty()) {
        $('ks-view-selector-filter-empty').show();
        $('ks-selector-filter').hide();
      }
      else {
        $('ks-view-selector-filter-empty').hide();
        $('ks-selector-filter').show();
      }

      ks_views.each(function(view) {
        var hview = $H(view);
        $(hview.get('idx')).removeClassName('ks-selector-selected');
        $(hview.get('idx')).show();

        var ks_match = hview.get('name').toLowerCase().indexOf(ks_selector_filter) >= 0;
        if (!ks_match) {
          $(hview.get('idx')).hide();
        }
      });

      ks_view_selector_first();
    }
  }

  // ----------------------------------------------------------------------- //
  // ----------------------------------------------------------------------- //

  /*
   * Job Selector stuff
   */

  var ks_job_selector_input;
  var ks_job_selector_selected;

  function ks_job_selector_select(job) {
    if (ks_is_job_selector) {
      ks_map_idx(ks_jobs).each(function(v) {
        $(v).removeClassName('ks-selector-selected');
      });

      if (typeof job != 'undefined') {
        ks_job_selector_selected = job;
        $(job).addClassName('ks-selector-selected');
        $('ks-selector-items-empty').hide();
      }
      else {
        $('ks-selector-items-empty').show();
      }
    }
  }

  function ks_job_selector_first() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_jobs);
    ks_job_selector_select(ks_matching[0]);
  }

  function ks_job_selector_last() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_jobs);
    ks_job_selector_select(ks_matching[ks_matching.length - 1]);
  }

  function ks_job_selector_next() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_jobs);
    var idx = ks_matching.indexOf(ks_job_selector_selected) + 1;
    if (idx >= ks_matching.length) {
      idx = 0;
    }

    ks_job_selector_select(ks_matching[idx]);
  }

  function ks_job_selector_open() {
    if (typeof ks_job_selector_selected != 'undefined') {
      ks_selector_hide();
      var item = ks_find_item_by_idx(ks_jobs, ks_job_selector_selected);
      if (item != null) {
        ks_set_window_location(ks_url + $H(item).get('url'));
      }
    }
  }

  function ks_job_selector_prev() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_jobs);
    var idx = ks_matching.indexOf(ks_job_selector_selected) - 1;
    if (idx < 0) {
      idx = ks_matching.length - 1;
    }

    ks_job_selector_select(ks_matching[idx]);
  }

  function ks_job_selector_show() {
    $('ks-selector').show();
    $('ks-job-selector-filter-empty').show();

    if (typeof ks_jobs != 'undefined') {
      $('ks-selector-items').innerHTML = ks_jobs.map(function(job) {
        return '<li id="#{idx}">#{name}</li>'.interpolate($H(job));
      }).join('');
    }

    ks_is_job_selector = true;
    ks_job_selector_first();
  }

  function ks_job_selector_filter() {
    if (ks_is_job_selector) {
      $('ks-selector-filter').innerText = ks_selector_filter;

      if (ks_selector_filter.empty()) {
        $('ks-job-selector-filter-empty').show();
        $('ks-selector-filter').hide();
      }
      else {
        $('ks-job-selector-filter-empty').hide();
        $('ks-selector-filter').show();
      }

      ks_jobs.each(function(job) {
        var hjob = $H(job);
        $(hjob.get('idx')).removeClassName('ks-selector-selected');
        $(hjob.get('idx')).show();

        var ks_match = hjob.get('name').toLowerCase().indexOf(ks_selector_filter) >= 0;
        if (!ks_match) {
          $(hjob.get('idx')).hide();
        }
      });

      ks_job_selector_first();
    }
  }

  // ----------------------------------------------------------------------- //
  // ----------------------------------------------------------------------- //

  /*
   * Node Selector stuff
   */

  var ks_node_selector_input;
  var ks_node_selector_selected;

  function ks_node_selector_select(node) {
    if (ks_is_node_selector) {
      ks_map_idx(ks_nodes).each(function(v) {
        $(v).removeClassName('ks-selector-selected');
      });

      if (typeof node != 'undefined') {
        ks_node_selector_selected = node;
        $(node).addClassName('ks-selector-selected');
        $('ks-selector-items-empty').hide();
      }
      else {
        $('ks-selector-items-empty').show();
      }
    }
  }

  function ks_node_selector_first() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_nodes);
    ks_node_selector_select(ks_matching[0]);
  }

  function ks_node_selector_last() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_nodes);
    ks_node_selector_select(ks_matching[ks_matching.length - 1]);
  }

  function ks_node_selector_next() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_nodes);
    var idx = ks_matching.indexOf(ks_node_selector_selected) + 1;
    if (idx >= ks_matching.length) {
      idx = 0;
    }

    ks_node_selector_select(ks_matching[idx]);
  }

  function ks_node_selector_open() {
    if (typeof ks_node_selector_selected != 'undefined') {
      ks_selector_hide();
      var item = ks_find_item_by_idx(ks_nodes, ks_node_selector_selected);
      if (item != null) {
        ks_set_window_location(ks_url + '/computer/' + $H(item).get('url'));
      }
    }
  }

  function ks_node_selector_prev() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_nodes);
    var idx = ks_matching.indexOf(ks_node_selector_selected) - 1;
    if (idx < 0) {
      idx = ks_matching.length - 1;
    }

    ks_node_selector_select(ks_matching[idx]);
  }

  function ks_node_selector_show() {
    $('ks-selector').show();
    $('ks-node-selector-filter-empty').show();

    if (typeof ks_nodes != 'undefined') {
      $('ks-selector-items').innerHTML = ks_nodes.map(function(node) {
        return '<li id="#{idx}">#{name}</li>'.interpolate($H(node));
      }).join('');
    }

    ks_is_node_selector = true;
    ks_node_selector_first();
  }

  function ks_node_selector_filter() {
    if (ks_is_node_selector) {
      $('ks-selector-filter').innerText = ks_selector_filter;

      if (ks_selector_filter.empty()) {
        $('ks-node-selector-filter-empty').show();
        $('ks-selector-filter').hide();
      }
      else {
        $('ks-node-selector-filter-empty').hide();
        $('ks-selector-filter').show();
      }

      ks_nodes.each(function(node) {
        var hnode = $H(node);
        $(hnode.get('idx')).removeClassName('ks-selector-selected');
        $(hnode.get('idx')).show();

        var ks_match = hnode.get('name').toLowerCase().indexOf(ks_selector_filter) >= 0;
        if (!ks_match) {
          $(hnode.get('idx')).hide();
        }
      });

      ks_node_selector_first();
    }
  }

  // ----------------------------------------------------------------------- //
  // ----------------------------------------------------------------------- //

  /*
   * Permalink Selector stuff
   */

  var ks_permalink_selector_input;
  var ks_permalink_selector_selected;

  function ks_permalink_selector_select(permalink) {
    if (ks_is_permalink_selector) {
      ks_map_idx(ks_permalinks).each(function(v) {
        $(v).removeClassName('ks-selector-selected');
      });

      if (typeof permalink != 'undefined') {
        ks_permalink_selector_selected = permalink;
        $(permalink).addClassName('ks-selector-selected');
        $('ks-selector-items-empty').hide();
      }
      else {
        $('ks-selector-items-empty').show();
      }
    }
  }

  function ks_permalink_selector_first() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_permalinks);
    ks_permalink_selector_select(ks_matching[0]);
  }

  function ks_permalink_selector_last() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_permalinks);
    ks_permalink_selector_select(ks_matching[ks_matching.length - 1]);
  }

  function ks_permalink_selector_next() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_permalinks);
    var idx = ks_matching.indexOf(ks_permalink_selector_selected) + 1;
    if (idx >= ks_matching.length) {
      idx = 0;
    }

    ks_permalink_selector_select(ks_matching[idx]);
  }

  function ks_permalink_selector_open() {
    if (typeof ks_permalink_selector_selected != 'undefined') {
      ks_selector_hide();
      var item = ks_find_item_by_idx(ks_permalinks, ks_permalink_selector_selected);
      if (item != null) {
        ks_set_window_location(ks_url + ks_url_job + $H(item).get('url'));
      }
    }
  }

  function ks_permalink_selector_prev() {
    var ks_matching = ks_filter_matching_idx(ks_selector_filter, ks_permalinks);
    var idx = ks_matching.indexOf(ks_permalink_selector_selected) - 1;
    if (idx < 0) {
      idx = ks_matching.length - 1;
    }

    ks_permalink_selector_select(ks_matching[idx]);
  }

  function ks_permalink_selector_show() {
    $('ks-selector').show();
    $('ks-permalink-selector-filter-empty').show();

    if (typeof ks_permalinks != 'undefined') {
      $('ks-selector-items').innerHTML = ks_permalinks.map(function(permalink) {
        return '<li id="#{idx}">#{name}</li>'.interpolate($H(permalink));
      }).join('');
    }

    ks_is_permalink_selector = true;
    ks_permalink_selector_first();
  }

  function ks_permalink_selector_filter() {
    if (ks_is_permalink_selector) {
      $('ks-selector-filter').innerText = ks_selector_filter;

      if (ks_selector_filter.empty()) {
        $('ks-permalink-selector-filter-empty').show();
        $('ks-selector-filter').hide();
      }
      else {
        $('ks-permalink-selector-filter-empty').hide();
        $('ks-selector-filter').show();
      }

      ks_permalinks.each(function(permalink) {
        var hpermalink = $H(permalink);
        $(hpermalink.get('idx')).removeClassName('ks-selector-selected');
        $(hpermalink.get('idx')).show();

        var ks_match = hpermalink.get('name').toLowerCase().indexOf(ks_selector_filter) >= 0;
        if (!ks_match) {
          $(hpermalink.get('idx')).hide();
        }
      });

      ks_permalink_selector_first();
    }
  }
}

0;
