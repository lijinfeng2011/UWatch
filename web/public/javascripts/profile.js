$(document).on('pageload', '#profile', function() {
    $('#methodBtn').click( ajaxSubmitMethod );
});

function changeText( value ) {
    var defaultType = $("input[name='defaultType']").val();
    var defaultAccount = $("input[name='defaultAccount']").val();
    var $txtBox = $("input[name='alarmAccount']");

    if ( value == defaultType ) { $txtBox.val(defaultAccount); return; } 
 
    if ( value == 'sms' )  { $txtBox.val('').attr('placeholder', '留个手机号码呗...'); }
    if ( value == 'blue' ) { $txtBox.val('').attr('placeholder', '留个蓝信账号呗...(手机号就行)'); }
    if ( value == 'zy' )   { $txtBox.val('').attr('placeholder', '留个智鹰组账号呗...'); }
    if ( value == 'qalarm' ) { $txtBox.val('').attr('placeholder', '留个Qalarm账号呗...'); }
}

function ajaxSubmitMethod() {
    var method = $("input[name='alarmType']:checked").val() || '';
    var account = $("input[name='alarmAccount']").val() || '';

    if ( !method.length ) { popOver('选个报警方式呗～'); return; }
    if ( !account.length) { popOver('留个账号信息呗～'); return; }

    var ajaxOpt = {
        url: "/ajaxSetMethod?value=" + method + '-' + account,
        before: showLoader,
        success: method_success,
        complete: hideLoader,
        error: ajax_error
    };

    sendAjaxRequest( ajaxOpt );

    function method_success(data) {
        if ( data.response === 1 ) { 
            popOver('Sorry，稍后再试下嘛！'); return;
        }

        if ( data.response === 0 ) { 
            popOver('接收报警方式设置成功～'); 
            $("input[name='defaultType']").val(method);
            $("input[name='defaultAccount']").val(account);
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

    var ajaxOpt = {
        url: encodeURI("/ajaxSetProfile" + param),
        before: showLoader,
        success: ajax_success,
        complete: hideLoader,
        error: ajax_error
    };

    sendAjaxRequest( ajaxOpt );
}

function triggerAlarm() {
    var check = $('#alarmValue').hasClass("ui-checkbox-on") ? 'off' : 'on';
        
    var ajaxOpt = {
        url: "/ajaxSetAlarm?value=" + check,
        before: showLoader,
        success: success_Alarm,
        complete: hideLoader,
        error: ajax_error
    };

    sendAjaxRequest( ajaxOpt );

    function success_Alarm( data ) {
        var check = $('#alarmValue').hasClass("ui-checkbox-on") ? 'off' : 'on';
        if ( data.response === 1 ) {
            popOver('Sorry，稍后再试下嘛！'); 
        } else if ( data.response === 0 ) {
            if ( check == 'on' ) {
                $('#fullFormat').checkboxradio('disable');
                $("input[type='radio']").checkboxradio('disable');
                $('#testBtn').button('disable');
                $('#methodBtn').button('disable');
                $("input[name='alarmAccount']").textinput('disable');
            } else {
                $('#fullFormat').checkboxradio('enable');
                $("input[type='radio']").checkboxradio('enable');
                $('#testBtn').button('enable');
                $('#methodBtn').button('enable');
                $("input[name='alarmAccount']").textinput('enable');
            }
            popOver('恭喜！成功了yeah～'); 
        }
    }
}

function triggerTest() {
    var ajaxOpt = {
        url: "/ajaxTriggerTest",
        before: showLoader,
        success: ajax_success,
        complete: hideLoader,
        error: ajax_error
    };
    sendAjaxRequest(ajaxOpt); 
}

function triggerFormat() {
    var check = $('#formatValue').hasClass("ui-checkbox-on") ? 'off' : 'on';
        
    var ajaxOpt = {
        url: "/ajaxSetFormat?value=" + check,
        before: showLoader,
        success: ajax_success,
        complete: hideLoader,
        error: ajax_error
    };

    sendAjaxRequest( ajaxOpt );
}

function ajaxChangePWD( event ) {
    if ( $('input[name="new-pwd"]').val() != $('input[name="confirm-pwd"]').val() )
    { popOver('两次密码不一样呦～'); return false; }
       
    var shouldReturn = false;
                                                                                   
    $.each ( $('input[type="password"]'), function(n, input) {
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

    var ajaxOpt = {
        url: "/ajaxChangePWD" + param,
        before: showLoader,
        success: success_PWD,
        complete: hideLoader,
        error: ajax_error
    };

    sendAjaxRequest( ajaxOpt );

    function success_PWD(data) {
        var responseHTML = '';
        if ( data.response === 1 ) { popOver('修改失败，稍后再试!'); }
        else if ( data.response === 0 ) { popOver('修改成功!'); }
        else if ( data.response === 2 ) { popOver('原始密码错误'); }
    }
}

