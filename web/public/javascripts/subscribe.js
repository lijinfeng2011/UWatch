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
        success: ajax_success,
        complete: hideLoader,
        error: ajax_error
    };

    sendAjaxRequest( ajaxOpt );
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
        var contentHtml = "";
        if ( data.subDetail != null && data.subDetail.length > 0 ) {
            contentHtml = '<div class="subscribe-box"><fieldset data-role="controlgroup">';
            $.each (data.subDetail, function( n, value ) {
                if ( value.level == 1 ) {
                    contentHtml = contentHtml + '<label for="' + value.name + '" style="color:orange">'+ value.name + '<p style="display:inline">&nbsp级别低</p>' + '</label>';
                } else if ( value.level == 3 ) {
                    contentHtml = contentHtml + '<label for="' + value.name + '" style="color:red">'+ value.name + '<p style="display:inline">&nbsp级别高</p>' + '</label>';
                } else {
                    contentHtml = contentHtml + '<label for="' + value.name + '">'+ value.name + '</label>';
                }
                if ( value.booked ) {
                    contentHtml = contentHtml + '<input type="checkbox" name="' + value.name + '" id="' + value.name + '" checked="checked">';
                } else {
                    contentHtml = contentHtml + '<input type="checkbox" name="' + value.name + '" id="' + value.name + '">';
                }
            });
            contentHtml = contentHtml + '</fieldset>';
            contentHtml = contentHtml + '<input type="hidden" name="hermesID" value="' + $target.attr("data-name") + '">';
            contentHtml = contentHtml + '<input type="button" onclick="ajaxFormSubmit(event)" value="提交选择">';
        } else {
            contentHtml = "<p>无法获得订阅信息!</p>";
        }
        $target.find('.content').html(contentHtml).trigger("create");
    }
}


