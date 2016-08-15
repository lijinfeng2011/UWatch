var TIMEOUT = 30;
var _countdown = 0;

$(document).on('pageload', '#profile', function() {
    $('#methodBtn').click( ajaxSubmitMethod );
});

$(document).on('pageshow', '#profile', function() {
    $('.filter-collapse').collapsible({
        expand: function(event, ui) { getFilterItems(); },
        collapse: function(event, ui) { $('#filterList').empty(); }
    });
    var check = $('#alarmValue').hasClass("ui-checkbox-on") ? 'on' : 'off';
    if ( check == 'off' ) {
        $(".alarm-change input[name='fullFormat']").checkboxradio('disable');
        $("#alarm-form input[type='button']").button('disable');
        $("#alarm-form input[type='text']").textinput('disable');
        $("#alarm-form input[type='tel']").textinput('disable');
        $("#alarm-form label").css('color', '#aaa');
    } else {
        $(".alarm-change input[name='fullFormat']").checkboxradio('enable');
        $("#alarm-form input[type='button']").button('enable');
        $("#alarm-form input[type='text']").textinput('enable');
        $("#alarm-form input[type='tel']").textinput('enable');
        $("#alarm-form label").css('color', '');
   }
});

$(document).on('pagehide', '#profile', function(){
    _countdown = 0; 
});

function getFilterItems() {
    sendAjaxRequest({ 
        url: "/ajaxGetFilterItems",
        before: showLoader,
        success: filterItems,
        complete: hideLoader,
        error: ajax_error });

    function filterItems(data) {
        var id = 0;
        var $list = $('#filterList');
        $.each (data.response, function(n, value) {
            var $li = $('<li></li>').appendTo($list);
            var $item = $('<div data-role="collapsible" class="filter-collapse" data-name="'+n+'">');
            $('<h3 style="margin: 0;"><span class="item">'+n+'</span></h3>').appendTo($item);

            var $nodeList = $('<div class="subscribe-box"></div>');
            var $fieldset = $('<fieldset data-role="controlgroup"></fieldset>').appendTo($nodeList);

            $.each (value, function(i, node) {
                var sp = node.split(':'); id++;             
                $('<label for="'+sp[0]+':'+ id +'">'+sp[0]+' (by:'+sp[1]+')</label>').appendTo($fieldset);
                if (sp[2] == '1') { 
                    $('<input type="checkbox" name="'+sp[0]+'" id="'+sp[0]+':'+id+'" onclick="filterRequest(event)" checked="checked">').appendTo($fieldset);
                } else {
                    $('<input type="checkbox" name="'+sp[0]+'" id="'+sp[0]+':'+id+'" disabled="disabled" checked="checked">').appendTo($fieldset);
                }
            });
                                 
            $nodeList.appendTo($('<div class="content"></div>').appendTo($item));
            $item.appendTo($li);
        });

        $('.filter-collapse').collapsible();
        $('.content').trigger("create");
    }
}

function filterRequest(event) {
    var fstatus = event.target.checked ? 1 : 0;
    var index = event.target.id,
        name = $(event.target).closest('.filter-collapse').attr('data-name');
    var keys = index.split(":");

    if ( fstatus == 1 ) {
        sendAjaxRequest({ 
            url: "/ajaxSetFilterMessage?name=" + name + '&node=' + keys[0],
            before: showLoader,
            success: set_success,
            complete: hideLoader,
            error: ajax_error });
     } else {
        sendAjaxRequest({ 
            url: "/ajaxDelFilterMessage?name=" + name + '&node=' + keys[0],
            before: showLoader,
            success: del_success,
            complete: hideLoader,
            error: ajax_error });
     }

    function del_success(data) {
        if ( data.response === 1 ) { popOver('Sorry，稍后再试下嘛！'); } 
        if ( data.response === 0 ) { popOver('取消屏蔽成功!'); } 
    }

    function set_success(data) {
        if ( data.response === 1 ) { popOver('Sorry，稍后再试下嘛！'); } 
        if ( data.response === 0 ) { popOver('屏蔽成功!'); } 
    }
}

function ajaxSubmitMethod() {
    var qArray = [];
    $.each($('#alarm-form input'), function(n, input) {
        var $input = $(input);
        if ( $input.val() && ($input.attr('type')=='tel' || $input.attr('type')=='text') ) {
            qArray.push($input.attr('name') + '-' + $input.val());
        }
    });
    
    if ( qArray.length == 0 ) { popOver('留个报警方式呗～'); return; }

    sendAjaxRequest({ 
        url: "/ajaxSetMethod?value=" + qArray.join(":"),
        before: showLoader,
        success: method_success,
        complete: hideLoader,
        error: ajax_error });

    function method_success(data) {
        if ( data.response === 1 ) { 
            popOver('Sorry，稍后再试下嘛！'); return;
        }

        if ( data.response === 0 ) { 
            popOver('接收报警方式设置成功～'); 
        } 
    }
}

function ajaxSubmitProfile( event ) {
    var param = "",
        follows = "",
        invalid = false; 
    var $targetForm = $(event.target).closest('#profile-form');

    $.each ( $targetForm.find('input'), function(n, input) { 
       var type = $(input).attr('type'),
           value = $(input).val();

       if ( type == 'tel' && !value.match( /^0?1[3|4|5|8][0-9]\d{8}$/ ) ) {
           popOver ("留个手机号码呗～");
           invalid = true; return false;
       }

       if ( type == 'tel' || type == 'text' || type == 'number' ) {
           if ( $(input).val().length == 0 && $(input).attr('name') != 'oncaller') { 
               popOver('要填写完整呦～');
               invalid = true; 
               return false; 
           }
           var token = param ? '&' : '?';
           token = token + $(input).attr('name') + "=" + $(input).val();
           param = param + token;
       }
    });

    if ( invalid ) return false;
    
    $.each ( $targetForm.find('option:selected'), function(n, option) {
        if ( follows.length ) { follows = follows + ':' + $(option).val(); }
        else { follows = follows + $(option).val(); }
    });

    if ( follows.length ) { param = param + '&follower=' + follows; }

    sendAjaxRequest({
        url: encodeURI("/ajaxSetProfile" + param),
        before: showLoader,
        success: ajax_success,
        complete: hideLoader,
        error: ajax_error });
}

function triggerAlarm() {
    var check = $('#alarmValue').hasClass("ui-checkbox-on") ? 'off' : 'on';

    sendAjaxRequest({ 
        url: "/ajaxSetAlarm?value=" + check,
        before: showLoader,
        success: success_Alarm,
        complete: hideLoader,
        error: ajax_error });

    function success_Alarm( data ) {
        var check = $('#alarmValue').hasClass("ui-checkbox-on") ? 'off' : 'on';
        if ( data.response === 1 ) {
            popOver('Sorry，稍后再试下嘛！'); 
        } else if ( data.response === 0 ) {
            if ( check == 'on' ) {
                $(".alarm-change input[name='fullFormat']").checkboxradio('disable');
                $("#alarm-form input[type='button']").button('disable');
                $("#alarm-form input[type='text']").textinput('disable');
                $("#alarm-form input[type='tel']").textinput('disable');
                $('#alarm-form label').css('color', '#aaa');
            } else {
                $(".alarm-change input[name='fullFormat']").checkboxradio('enable');
                $("#alarm-form input[type='button']").button('enable');
                $("#alarm-form input[type='text']").textinput('enable');
                $("#alarm-form input[type='tel']").textinput('enable');
                $("#alarm-form label").css('color', '');
                if ( _countdown > 0 ) $('#testBtn').button('disable');
            }
            popOver('恭喜！成功了yeah～'); 
        }
    }
}

function triggerTest() {
    sendAjaxRequest({
        url: "/ajaxTriggerTest",
        before: showLoader,
        success: ajax_success,
        complete: hideLoader,
        error: ajax_error }); 

    $('#testBtn').button('disable');
    _countdown = TIMEOUT; 
    refreshBtn( $('#testBtn') );
}

function refreshBtn( btn ) {
    if ( _countdown === 0 ) {
        btn.val('设置测试').button("refresh");
        if ($('#alarmValue').hasClass("ui-checkbox-on")) {
            btn.button('enable');
        }
    } else {
        btn.val( '剩余' + --_countdown + '秒' ).button("refresh");
        setTimeout( function(){ refreshBtn(btn)}, 1000 );
    }
}

function triggerFormat() {
    var check = $('#formatValue').hasClass("ui-checkbox-on") ? 'off' : 'on';
    sendAjaxRequest({
        url: "/ajaxSetFormat?value=" + check,
        before: showLoader,
        success: ajax_success,
        complete: hideLoader,
        error: ajax_error });
}

function ajaxChangePWD( event ) {
    if ( $('input[name="new-pwd"]').val() != $('input[name="confirm-pwd"]').val() )
    { popOver('两次密码不一样呦～'); return false; }
       
    var shouldReturn = false;
                                                                                   
    $.each ( $('input[type="password"]'), function(n, input) {
       if ( $(input).attr('name') == 'old-pwd' ) { return true; }

       var value = $(input).val();

       if ( value.length < 6 ) { popOver('长度不小于6位呦～'); shouldReturn = true; return false; }
          
       var reg = new RegExp("[a-zA-Z]");
       if ( !reg.test(value) ) { popOver('至少包含一个字母呦～'); shouldReturn = true; return false; }

       reg = new RegExp("[0-9]");
       if ( !reg.test(value) ) { popOver('至少包含一个数字呦～'); shouldReturn = true; return false; }

       reg = new RegExp("[/#?@]");
       if ( reg.test(value) ) { popOver('不能包含/#?@符号呦～'); shouldReturn = true; return false; }
    });

    if ( shouldReturn ) { return false; }

    var old_pwd = $.md5( $('input[name="old-pwd"]').val() );
    var new_pwd = $.md5( $('input[name="new-pwd"]').val() );
    var param = '?old=' + old_pwd + '&new=' + new_pwd;

    sendAjaxRequest({
        url: "/ajaxChangePWD" + param,
        before: showLoader,
        success: success_PWD,
        complete: hideLoader,
        error: ajax_error });

    function success_PWD(data) {
        var responseHTML = '';
        if ( data.response === 1 ) { popOver('修改失败，稍后再试!'); }
        else if ( data.response === 0 ) { popOver('修改成功!'); }
        else if ( data.response === 2 ) { popOver('原始密码错误'); }
    }
}

