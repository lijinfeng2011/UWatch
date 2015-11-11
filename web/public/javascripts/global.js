var $page = null;

$(document).on('pageinit', function() {
    if ( $('#go-top').length ) {
        $('#go-top').hide();
        return;
    }

    ( new GoTop() ).init({
        pageWidth: $(window).width(),
        nodeId: 'go-top',
        nodeWidth: 50,
        distanceToBottom: 125,
        hideRegionHeight: 130,
        distanceToPage: 20,
        zIndex: 100,
        text: ' '});
});
    
$(document).on('pagebeforeshow', function() {
    window.history.replaceState(null, null, '/'); 
});

$(document).on('pageload', function() {
    setTimeout(function(){ $page.trigger('click'); }, 1500);
});

$(document).on("pagecreate", function(e) {
    $page = $(e.target);
    var pageId = $page.attr('id');
    if ( pageId != 'mesgDetail' ) {
        createFooter($page,pageId);
        pageRefresh();
    }
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
    $('<div data-role="popup" id="popupDialog" data-confirmed="yes" data-transition="pop" data-overlay-theme="a" data-theme="a" style="width:18em"><div data-role="header" data-theme="b"><h1>亲!</h1></div><div role="main" class="ui-content"><h3 class="ui-title">' + content + '</h3></div></div>').appendTo($.mobile.pageContainer);

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
    setTimeout(function(){$popupObj.popup('close');}, 1200);
}

function sendAjaxRequest( Opt ) {
    $.ajax({
        async:       true,
        timeout:     3000,
        type:        'post',  
        url :        Opt['url'],
        dataType:    'json',
        contentType: 'application/json',
        beforeSend:  function()     { Opt['before']();      },
        success:     function(data) { Opt['success'](data); },
        complete:    function()     { Opt['complete']();    },  
        error:       function(XMLHttpRequest, textStatus, errorThrown){ alert(textStatus); Opt['error'](); }
    });
}

function ajax_success(data) {
    if ( data.response === 1 ) { popOver('Sorry，稍后再试下嘛！'); } 
    if ( data.response === 0 ) { popOver('恭喜！成功了yeah～'); } 
}

function ajax_error() { popOver('链路失败，稍后再试下嘛！'); }
