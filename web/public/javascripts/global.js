var $page = null;

$(document).on('mobileinit', function() {
    $.mobile.defaultPageTransition = 'none';
    $.mobile.buttonMarkup.hoverDelay = 10;
//    $.support.cors = true;
//    $.mobile.allowCrossDomainPages = true;
    $('.ui-body-c, .ui-overlay-c').css('background', $(".contentc", $.mobile.activePage).css('background'));
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
