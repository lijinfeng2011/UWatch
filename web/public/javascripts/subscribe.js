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
                    contentHtml = contentHtml + '<p style="display:inline"> '+ value.alias +'</p></label>';
                } else {
                    contentHtml = contentHtml + '</label>';
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


