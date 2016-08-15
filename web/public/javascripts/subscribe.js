var nodes = null;
var shouldOpenSMT = false;

$(document).on('pageshow', '#pageSubscribe', function() {
    $("#filterPanel").panel({
        beforeclose: function (event, ui) {
            setTimeout(closeFilterPanel, 500);
        }
    });
    $("#searchPanel").panel({
        beforeclose: function (event, ui) {
            if (shouldOpenSMT) {
                $('#smt-form').show();
                shouldOpenSMT = false;
            }
        }
    });

    $('#openFilterPanel').unbind('click', openFilterPanel).bind('click', openFilterPanel);
    $('#openSearchPanel').unbind('click', openSearchPanel).bind('click', openSearchPanel);

    $('#bizGroup').unbind('click', filterBusiness).bind('click', filterBusiness);

    $('#nsForm').unbind('submit', searchNode).bind('submit', searchNode);
    $('#nsForm .ui-input-clear').unbind('click', searchNode)
                                .bind('click', searchNode);

    $('#hsForm').unbind('submit', searchHermes).bind('submit', searchHermes);
    $('#hsForm .ui-input-clear').unbind('click', searchHermes)
                                .bind('click', searchHermes);
});

$(document).on('pagebeforehide', '#pageSubscribe', function() {
    Panel.closeSMT();
});

function ajaxFormSubmit( event ) {
    var param = ""; var token = "";
    var $targetBox = $(event.target).closest('.subscribe-box');

    $.each ( $targetBox.find('.ui-checkbox'), function(n, item) {
        var name = $(item).find('input[type="checkbox"]').attr("name");
        var value = $(item).find('label').hasClass("ui-checkbox-on") ? 1 : 0;
        if (param) { token = "&" + name + "=" + value; }
        else { token = "?" + name + "=" + value; }
        param = param + token;
    });
    param = param + "&hermesID=" + $targetBox.find('input[name="hermesID"]').val();

    var ajaxOpt = {
        url:"/ajaxBookSubscribe" + param,
        before: showLoader,
        success: success_smt,
        complete: hideLoader,
        error: ajax_error
    };

    sendAjaxRequest( ajaxOpt );

    function success_smt(data) {
        if (data.response === 0) { popOver('恭喜！成功了yeah～'); }
        if (data.response === 1) { popOver('Sorry，稍后再试下嘛！'); }
        if (data.response === 2) { popOver('请先添加接受报警方式后再订阅！'); }
        if (data.response === 3) { popOver('订阅成功，记得打开接收报警选项哦～'); }
    }
}

function ajaxGetSubDetail( target ) {
    var $target = target;
    var ajaxOpt = {
        url: "/ajaxGetSubDetail?group=" + $target.attr("data-name"),
        before: showLoader,
        success: success_get,
        complete: hideLoader,
        error: ajax_error
    };

    sendAjaxRequest( ajaxOpt );

    function success_get(data) {
        var contentHtml = "", isOpened = 0;
        if ( data.subDetail != null && data.subDetail.length > 0 ) {
            contentHtml = '<div class="subscribe-box"><fieldset data-role="controlgroup">';
            $.each (data.subDetail, function( n, value ) {
                if ( value.level == 1 ) {
                    contentHtml = contentHtml + '<label for="' + value.name + '" style="color:orange">'+ value.name + '<p style="display:inline">&nbsp级别低</p>';
                } else if ( value.level == 3 ) {
                    contentHtml = contentHtml + '<label for="' + value.name + '" style="color:red">'+ value.name + '<p style="display:inline">&nbsp级别高</p>';
                } else {
                    contentHtml = contentHtml + '<label for="' + value.name + '">'+ value.name;
                }

                if ( value.alias ) {
                    contentHtml = contentHtml+'<p style="display:inline"> '+value.alias+'</p></label>';
                } else {
                    contentHtml = contentHtml+'</label>';
                }

                if ( value.booked ) {
                    contentHtml = contentHtml + '<input type="checkbox" name="' + value.name + '" id="' + value.name + '" checked="checked">';
                } else {
                    contentHtml = contentHtml + '<input type="checkbox" name="' + value.name + '" id="' + value.name + '">';
                }
            });
            contentHtml = contentHtml + '</fieldset>';
            contentHtml = contentHtml + '<input type="hidden" name="hermesID" value="' + $target.attr("data-name") + '">';
            contentHtml = contentHtml + '<input type="button" onclick="ajaxFormSubmit(event)" value="提交选择"></div>';
           
            isOpened = 1;
        } else {
            contentHtml = "<p>无法获得订阅信息!</p>";
        }
        $target.find('.content').html(contentHtml).trigger("create");
        if (Panel) { Panel.openSMT($target); }
    }
}

function openSearchPanel() {
    var $smtPanel = $('#smt-form');
    var $target = Panel.getOpenedForm();
    if ( $smtPanel.is(':visible') && $target ) {
       $('#hsForm').find('input[name="hermesName"]').val($target.attr('data-name'));
       $('#smt-form').hide();
       shouldOpenSMT = true;
    } else {
       shouldOpenSMT = false;
       $('#hsForm').find('input[name="hermesName"]').val('');
    } 
    searchHermes();
}

// Filter Panel Functions;
function openFilterPanel() {
   if (localStorage.filterBiz) {
       var tmp = localStorage.filterBiz.split("-");
       for (var idx in tmp) {
           $("input[name='"+tmp[idx]+"']").attr("checked",true).checkboxradio("refresh"); 
       }
   }

   if (sessionStorage.getItem('filterNode')) {
       $('input[name="nodeName"]').val( sessionStorage.getItem('filterNode') );    
   }

   if (sessionStorage.getItem('filterBizs')) {
       var $nodeList = $('#nodeFilterList');
       var tmp = sessionStorage.getItem('filterBizs').split(":");
       for (var idx in tmp) {
           $('<li>'+ tmp[idx] +'</li>').appendTo($nodeList);
       }
       $nodeList.listview('refresh');
   }
}

function filterBusiness(event) {
    var $target = $(event.target).closest('.ui-checkbox');
    var bizArray = new Array();

    $.each( $('#bizGroup').find('.ui-checkbox'), function(n, biz) {
       var $bizLabel = $(biz).find('label');
       if ( $(biz).get(0) == $target.get(0) ) {
           if ( $bizLabel.hasClass("ui-checkbox-off") ) {
              bizArray.push( $bizLabel.text() );
           }
       } else {
           if ( $bizLabel.hasClass("ui-checkbox-on") ) {
              bizArray.push( $bizLabel.text() );
           }
       }
    });

    if ( bizArray.length > 0 ) { localStorage.filterBiz = bizArray.join('-'); } 
    else { localStorage.filterBiz = ''; }
}

function closeFilterPanel() {
   var fbiz = ( sessionStorage.getItem('filterBizs') && 
                sessionStorage.getItem('filterBizs') != null )
              ? sessionStorage.getItem('filterBizs') : '';

    var url = $("#bizSetting").attr('action') + '?fname=' + localStorage.filterBiz + '&fbiz=' + fbiz;
    $("#bizSetting").attr('action', url).submit();
}

function searchNode( event ) {
    event.preventDefault(); 
    event.stopPropagation();
 
    nodes = $('input[name="nodeName"]').val();
    nodes = nodes.replace(/(^\s*)|(\s*$)/g, '');
  
    if ( !nodes ) { 
        sessionStorage.setItem('filterNode', '');
        sessionStorage.setItem('filterBizs', '');
        $('#nodeFilterList').empty();
        return false; 
    }

    sendAjaxRequest({
        url: "/ajaxGetBizByNode?node=" + nodes,
        before: showLoader,
        success: update_biz,
        complete: hideLoader,
        error: ajax_error
    });

    return false;

    function update_biz(data) {
        var hasItem = false, bizArray = new Array();
        var $nodeList = $('#nodeFilterList');

        $nodeList.empty();
        $('#mbox-bizs').show();
        $.each (data.bizList, function(n, item){
            $('<li>'+ item +'</li>').appendTo($nodeList);
            bizArray.push(item); 
            hasItem = true;
        });

        if (hasItem) {
            $('#mbox-bizs').hide();
            $nodeList.listview('refresh');
        }

        if ( bizArray.length ) {
            sessionStorage.setItem('filterNode', nodes);
            sessionStorage.setItem('filterBizs', bizArray.join(':'));
        } else {
            sessionStorage.setItem('filterNode', '');
            sessionStorage.setItem('filterBizs', '');
        } 
    }
}

function searchHermes( event ) {
    event && event.preventDefault(); 
    event && event.stopPropagation();

    var $diagramList = $('#diagramList').empty();
    var $hermesList = $('#hermesFilterList').empty();

    var hermes = $('input[name="hermesName"]').val();
    hermes = hermes.replace(/(^\s*)|(\s*$)/g, '');
  
    if (!hermes) { return false; }

    var digArray = ['CPU', 'MEM', 'IFACE', 'LOAD'],
        smImage = '/getGraph?small=1&name=' + hermes,
        bgImage = '/getGraph?small=0&name=' + hermes,
        noImage = '/images/no_image.jpg';

    $.each( digArray, function(n, key){
        $('<li data-role="list-divider"></li>').text(key + '图表').appendTo($diagramList);

        $('<a target="_blank"></a>').attr('href', bgImage+'&type='+key)
            .html('<img width="240" height="130" onerror="this.src=&quot'+noImage+'&quot" src="'+smImage+'&type='+key+'">')
            .appendTo($diagramList);
    });

    $diagramList.listview('refresh');

    sendAjaxRequest({
        url: "/ajaxGetNodesByHermes?hermes=" + hermes,
        before: showLoader,
        success: update_nodes,
        complete: hideLoader,
        error: ajax_error
    });

    function update_nodes(data) {
        var hasItem = false;

        $('#mbox-hermes').show();
        $.each (data.nodesList, function(room, nodes) {
            $('<li data-role="list-divider">'+ room +'</li>').appendTo($hermesList);
            $.each(nodes, function(n, node) {
                $('<li>'+ node +'</li>').appendTo($hermesList);
            });
            hasItem = true;
        });

        if (hasItem) {
            $('#mbox-hermes').hide();
            $hermesList.listview('refresh');
        }
    }

}
