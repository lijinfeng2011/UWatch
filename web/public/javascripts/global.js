var $page = null;
var Panel = null;

$(document).on('pageinit', function() {
    if ($('#go-top').length) {
        $('#go-top').hide();
    } else {
        Panel = new GoTop();
        Panel.init({
            pageWidth: $(window).width(),
            topNodeId: 'go-top',
            smtNodeId: 'smt-form',
            nodeWidth: 50,
            distanceToBottom: 125,
            hideRegionHeight: 130,
            distanceToPage: 20,
            zIndex: 1000,
            text: ' '});
    }
});
    
$(document).on('pagebeforeshow', function() {
    if ( typeof window.history.replaceState === 'function' ) {
        window.history.replaceState(null, null, '/'); 
    }
});

$(document).on('pageload', function() {
    setTimeout(function(){ $page.trigger('click'); }, 1500);
});

$(document).on('pageshow', '#mesgDetail', function() {
    createGraphy();
});

$(document).on('pageshow', '#pageHomepage', function() {
    if( $('#pageGlance').length ) $('#pageGlance').remove(); 
});

$(document).on('pageshow', '#pageGlance', function() {
    if( $('#pageHomepage').length ) $('#pageHomepage').remove(); 
});

$(document).on("pagecreate", function(e) {
    $page = $(e.target);
    var pageId = $page.attr('id');
    if ( pageId == 'mesgDetail' ) {
    } else {
        createFooter($page,pageId);
        pageRefresh();
    }
});

$(document).on('click', '#following-dialog .ui-icon-delete', function(event){
    $(this).attr('href', '/profile');
});

function pageRefresh(){
    $.mobile.pageContainer.trigger("create");
}

function createFooter(page, id) {
    var footerUrl = page.attr("data-footer");

    if (footerUrl) {
        var footerHtml = '';
        if (!footerHtml) {
            footerHtml = urlLoadContent(footerUrl);
        }

        page.append(footerHtml);
        if (id == 'pageGlance') {
            page.find('a[data-icon="grid"]').attr('class', "ui-btn-active ui-state-persist")
                                            .attr('href', '#');
            page.find('a[data-icon="plus"]').attr('href', '/subscribe')
                                            .attr('data-transition', 'slide');
            page.find('a[data-icon="gear"]').attr('href', '/profile')
                                            .attr('data-transition', 'slide');
        } else if (id == 'profile') {
            page.find('a[data-icon="grid"]').attr('href', '#pageGlance')
                                            .attr('data-transition', 'slide')
                                            .attr('data-direction', 'reverse');
            page.find('a[data-icon="plus"]').attr('href', '/subscribe')
                                            .attr('data-transition', 'slide')
                                            .attr('data-direction', 'reverse');
            page.find('a[data-icon="gear"]').attr('class', "ui-btn-active ui-state-persist")
                                            .attr('href', '#');
        } else if (id == 'pageSubscribe') {
            page.find('a[data-icon="grid"]').attr('href', '#pageGlance')
                                            .attr('data-transition', 'slide')
                                            .attr('data-direction', 'reverse');
            page.find('a[data-icon="plus"]').attr('href', '#')
                                            .attr('class', 'ui-btn-active ui-state-persist')
            page.find('a[data-icon="gear"]').attr('href', '/profile')
                                            .attr('data-transition', 'slide');
        } else if (id == 'pageHomepage') {
            page.find('a[data-icon="grid"]').attr('href', '/login')
                                            .attr('data-rel', 'dialog');
            page.find('a[data-icon="plus"]').attr('href', '/login')
                                            .attr('data-rel', 'dialog');
            page.find('a[data-icon="gear"]').attr('href', '/login')
                                            .attr('data-rel', 'dialog');
        } else if (id == 'pageLoginError') {
            page.find('a[data-icon="grid"]').attr('href', '/login')
                                            .attr('data-rel', 'dialog');
            page.find('a[data-icon="plus"]').attr('href', '/login')
                                            .attr('data-rel', 'dialog');
            page.find('a[data-icon="gear"]').attr('href', '/login')
                                            .attr('data-rel', 'dialog');
        }
    }
}

var urlLoadContent = function(url) {
    var content = "";
    $.ajax({
        url : url,
        type : 'GET',
        dataType : "html",
        async : false,
        success : function(html, textStatus, xhr) {
            content = html;
        },
        error : function(xhr, textStatus, errorThrown) {
            content = "";
        }
    });

    return content;
};

function showLoader() {
    $.mobile.loading('show', {
        textVisible: true,
        dataType: "json",
        theme: 'a',
        textonly: false,
        html: ""
    });
}

function hideLoader() { $.mobile.loading('hide'); }

function popOver(content, callback) {
    $('<div data-role="popup" id="popupDialog" data-confirmed="yes" data-transition="pop" data-overlay-theme="a" data-theme="a" class="g-popover"><div data-role="header" data-theme="b"><h1>亲!</h1></div><div role="main" class="ui-content"><h3 class="ui-title">' + content + '</h3></div></div>').appendTo($.mobile.pageContainer);

    var $popupObj = $('#popupDialog');
    $popupObj.trigger('create');
    $popupObj.popup({  
        history: false,
        afterclose: function (event, ui) {  
            $popupObj.find(".optionConfirm").first().off('click');  
            var isConfirmed = $popupObj.attr('data-confirmed') === 'yes' ? true : false;  
            $(event.target).remove();  
            if (isConfirmed && callback) { callback(); }  
        } });
    $popupObj.popup('open');
    setTimeout(function(){$popupObj.popup('close');}, 1500);
}

function popConfirmation(data, callback) {
    $('<div data-role="popup" id="popupConfirm" data-confirmed="no" data-transition="pop" data-overlay-theme="a" data-theme="a" class="g-popover"><div data-role="header" data-theme="b"><h1>确认</h1></div><div role="main" class="ui-content confirmDlg"><h3 class="ui-title">您将屏蔽包含如下信息的机器</h3></div></div>').appendTo($.mobile.pageContainer);

    var $ul = $('<ul data-role="listview" style="margin-top:1em;"></ul>');
    var els = data.nodes.split(':');
    for ( var i in els ) {
        $('<li>' + els[i] + '</li>').appendTo($ul);
    }
    $ul.appendTo('.confirmDlg');

    var $btnGroup = $('<div data-role="controlgroup" data-mini="true" style="margin-top:2em">').appendTo('.confirmDlg');
    var $btnNo = $('<button data-icon="back">取消屏蔽</button>').appendTo($btnGroup);
    var $btnYes = $('<button data-icon="check">确认屏蔽</button>').appendTo($btnGroup);

    $('<input id="filterNodes" type="hidden" value="'+ data.hermes +'">').appendTo('.confirmDlg');
    $('<input id="filterName" type="hidden" value="'+ data.name +'">').appendTo('.confirmDlg');
    $('<input id="filterTime" type="hidden" value="'+ data.time +'">').appendTo('.confirmDlg');

    var $popupObj = $('#popupConfirm');
    $popupObj.trigger('create');
    $popupObj.popup({  
        history: false,
        afterclose: function (event, ui) {  
            $popupObj.find(".optionConfirm").first().off('click');  
            var isConfirmed = $popupObj.attr('data-confirmed') === 'yes' ? true : false;  
            $(event.target).remove();  
            if (isConfirmed && callback) { callback(); }  
        } 
    });
    $popupObj.popup('open');

    $btnNo.unbind('click')
          .bind('click', function(){ $('#popupConfirm').popup('close') });

    $btnYes.unbind('click')
           .bind('click', function(){ 
               $('#popupConfirm').popup('close');

               var hName = $('#filterName').val(),
                   hermes = $('#filterNodes').val(),
                   hTime = $('#filterTime').val();

               sendAjaxRequest({
                   url: '/ajaxSetFilterMessageGrp?name='+hName+'&hms='+hermes+'&time='+hTime,
                   before: function(){},
                   complete: function(){},
                   error: function(){},
                   success: function( data ) {
                       if ( data.response == 1 ) {
                           popOver('屏蔽失败!');
                       } else if ( data.response == 2 ) {
                           popOver('一次不能超过20台机器!');
                       } else if ( data.response == 3 ) {
                           popOver('机器格式不合法!');
                       } else {
                           setTimeout(function(){ popOver('屏蔽成功了yeah~!');  }, 1000);
                       }
                   }
               });
           });
}

function sendAjaxRequest( Opt ) {
    $.ajax({
        async:       true,
        timeout:     5000,
        type:        'post',  
        url :        Opt['url'],
        dataType:    'json',
        contentType: 'application/json',
        beforeSend:  function()     { Opt['before']();      },
        success:     function(data) { Opt['success'](data); },
        complete:    function()     { Opt['complete']();    },  
        error:       function(XMLHttpRequest, textStatus, errorThrown){ 
                         if (textStatus === "timeout" ) {
                             popOver('连接超时，稍后再试下嘛！');
                         }
                         Opt['error'](); 
                     }
    });
}

function ajax_success(data) {
    if ( data.response === 1 ) { popOver('Sorry，稍后再试下嘛！'); } 
    if ( data.response === 0 ) { popOver('恭喜！成功了yeah～'); } 
}

function ajax_error() { popOver('链路失败，稍后再试下嘛！'); }

function showGraphy(data) {
    var value = [],
        tmpArray = [],
        stringTime,
        content = data.response,
        myDate = new Date(),
        micTime = myDate.getTime();

    if ( content.length ) {
        tmpArray = data.response.split("\n");
        var index = tmpArray.length - 1;
        var key = [];
        var maxY = 0;

        for (var count = 0; count < 1440; count++) {
            var mTime = micTime - count * 1000 * 60;
            var newDate = new Date( mTime );
            var newMonth = newDate.getMonth() + 1;
            var stringTime = newDate.getFullYear() + '-' + newMonth + '-' + newDate.getDate() + '-' + newDate.getHours() + '-' + newDate.getMinutes();
            
            key = index >= 0 ? tmpArray[index].split(':') : [];
            var curIndex = 1440 - count;
            if ( key.length == 2 && stringTime == key[0]) {
                index--;
                value.push([curIndex, key[1]]);
                if ( parseInt(key[1]) > parseInt(maxY) ) maxY = key[1];
            } else {
                value.push([curIndex, 0]);
            } 
        }
    }

    var y_max = maxY > 0 ? maxY : 2;
    var baseTime = micTime - 1440 * 1000 * 60;

    var timeTickFormatter = function (format, val) {  
        if (typeof val == 'number') {  
            if ( (""+val).indexOf(".") === -1 ) {
                var curTime = new Date(baseTime + val*60*1000);
                return curTime.getDate() + '-' + curTime.getHours() + ':' + curTime.getMinutes();
            }  
            return "";  
        }  
        else {  
            return String(val);  
        }  
    }; 
   
    var y_array=[0];
    for (var id=1; id<11; id++) {
        y_array.push(parseInt(y_max*id/10));
    }

    y_array.push(Math.ceil(y_max * 1.05));

    var opt = {
        axes: {
            xaxis: { 
                min: 0, 
                max: 1440,
                pad: 1.0,
                tickOptions: { formatter: timeTickFormatter }  
            },
            yaxis: { 
                min: 0,
              //  max: Math.ceil(y_max),
                ticks: y_array, 
            },
        },
        seriesDefaults: {
            showMarker: false,
            lineWidth: 0.5,
            shadowOffset: 1,
        },
        title: {
            text: '24小时内报警分布图',
            show: true,
        },
    }; 

    $.jqplot('plotChart', [value.reverse()], opt);
}

function createGraphy() {
    var hermesName = $('.hermesName').text();

    var ajaxOpt = {
        url: encodeURI("/ajaxGetRecords?hermes=" + hermesName),
        before: function(){},
        success: showGraphy,
        complete: function(){},
        error: function(){}
    };

    sendAjaxRequest( ajaxOpt );
}

function submitSubForm(target) {
    target.find('input[type="button"]').trigger('click');
//    var txt = target.find('.alias').text();
//    alert(txt);
    
}

