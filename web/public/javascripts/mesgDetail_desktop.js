var pullUpEl   = document.getElementById('pullUp'),
    pullDownEl = document.getElementById('pullDown'),
    $mesgList  = $('#contentList1'),
    $target = null;

//var popover_timeout = null;

$(document).on('pagebeforeshow', '#mesgDetail', function() {
    if (sessionStorage.getItem('glanceView') == 'oncall') {
        $('#cancelBtn').attr('disabled', 'true');
    }
});

$(document).on('pagebeforehide', '#mesgDetail', function() {
    $('.webui-popover').remove();
});

$(document).on('pageshow', '#mesgDetail', function() {
    //$('#mesgDetail #contentList1 li').off('mouseenter mouseleave')
    //    .on('mouseenter',$.proxy(mouseEnterHandler, this))
    //    .on('mouseleave',$.proxy(mouseLeaveHandler, this));
//    $('#mesgDetail #contentList1 li').off('click')

    $('#mesgDetail #contentList1').undelegate('li', 'click', showPopover)
                                  .delegate('li', 'click', showPopover);
//    $('#mesgDetail #contentList1').off('click')
//        .on('click', showPopover);
//        .on('click', $.proxy(showPopover, this));
});

//function mouseEnterHandler(element) {
//    var node = $(element.target).find('.node').text();
//    if (popover_timeout) { clearTimeout(popover_timeout); }

//    popover_timeout = setTimeout( function(){
//        showPopover1($(element.target));
//    }, 1000 );
//}

//function mouseLeaveHandler(element) {
//    if (popover_timeout) { clearTimeout(popover_timeout); }
//}

function showPopover( event, type ) {
    if (type === "fake") { return false; }

    if ( $target && $target.get(0) == $(event.currentTarget).get(0) ) {
        $target = null;
        $('.webui-popover').remove();
        return;
    }

    $target = $(event.currentTarget);
    var node = $target.find('.node').text();

    var pos = $target.offset().top - $(document).scrollTop() < 400 ? 'bottom' : 'top';

    $('.webui-popover').remove();

    var settings = {
        placement: pos,
        trigger:   'click',
        title:     '详细信息',
        width:     1060,
        height:    310,
        multi:     false,
        closeable: true,
        style:     '',
        arrow:     true,
        padding:   true };

    var asyncSettings = {
        cache:    false,
        url:      '/ajaxGetNodeDetail?node=' + node,
        type:     'async',
        dataType: 'json',
        content: function(data) {
            var $popModel = $('#popover-model').clone();
            $.each (data.detail, function(key, value) {
                if ( key === 'node' ) {
                    $popModel.find('#machineName').text(value);
                } else if ( key === 'hermes' ) {
                    $popModel.find('#bizName').text(value);
                } else if ( key === 'oncaller' ) {
                    $popModel.find('#oncaller').text(value);
                }
            });
            var tmp = $target.find('.detail').text().split('#');
            var machine = $popModel.find('#machineName').text();
            var tmarray = tmp[0].split(machine);
            $popModel.find('#alarmTime').text(tmarray[0]); 
            $popModel.find('#alarmInfo').text(tmp[1]);

            var GrArray = ['CPU', 'MEM', 'IFACE', 'LOAD'];
            var smImage = '/getGraph?small=1&name=' + machine;
            var bgImage = '/getGraph?small=0&name=' + machine;

            $.each( GrArray, function(n, key){
               $popModel.find('#'+key).attr('src', smImage+'&type='+key)
                                      .closest('a').attr('href', bgImage+'&type='+key);
            });

            $('<input name="stopPrd" id="stopPrd" placeholder="选择时间间隔" data-role="datebox">').attr('data-options', '{"mode":"durationbox"}').appendTo($popModel.find('.stopAlarm')); 
            $('<input name="stopPrdGrp" id="stopPrdGrp" placeholder="时间间隔" data-role="datebox">').attr('data-options', '{"mode":"durationbox"}').appendTo($popModel.find('.stopAlarmGrp')); 
            setTimeout( function(){ 
                $('#stopPrd').textinput().datebox(); 
                $('#stopPrdGrp').textinput().datebox(); 
            }, 100 ); 
            return $popModel.css('display', 'inline-block').html(); } 
       };
  
    $target.webuiPopover('destroy')
           .webuiPopover($.extend({}, settings, asyncSettings))
           .trigger('click', ['fake']);
}

function pullUpAction ( data ) {
    $('.webui-popover').remove();
    setTimeout(function () {
        var content = '', count = 0;
        $.each( data.response, function( n, mesg ) {
            count++;
            content = content + '<li class="gary"><span class="index hide">';
            content = content + mesg.idx;
            content = content + '</span><span class="node hide">';
            content = content + mesg.node;
            content = content + '</span><span class="detail"> ';
            content = content + mesg.content;
            content = content + '</span></li>';
        });

        if ( count > 0 ) {
            var number = parseInt($('.listHeader').find('.count').text()) + count;
            $('.listHeader').find('.count').text(number);
        }

        $mesgList.append(content).listview('refresh');
        pullUpEl.className = '';
        pullUpEl.querySelector('.pullUpLabel').innerHTML = '点击此处获取历史数据...';

    }, 100);
}

function pullDownAction( data ) {
    $('.webui-popover').remove();
    setTimeout( function () {
        var content = '', count = 0;
        $.each( data.response, function( n, mesg ) {
            count++;
            content = content + '<li data-swipeurl="#"><span class="index hide">';
            content = content + mesg.idx;
            content = content + '</span><span class="node hide">';
            content = content + mesg.node;
            content = content + '</span><span class="detail"> ';
            content = content + mesg.content;
            content = content + '</span></li>';
        });

        $mesgList.find('li').removeClass('gary').addClass('gary');
        $('.filterBtn').attr('disabled','true');
        var number = parseInt($('.listHeader').find('.count').text()) + count;
        $('.listHeader').find('.count').text(number);

        $mesgList.prepend(content).listview('refresh');
        pullDownEl.className = '';
        pullDownEl.querySelector('.pullDownLabel').innerHTML = '点击此处获取最新数据...';

    }, 100);
}

function getHistory() {
    pullUpEl.className = 'loading';
    pullUpEl.querySelector('.pullUpLabel').innerHTML = '加载中...';
   
    var last = $("#contentList1>li:last").find('.index').text();
    sendAjaxRequest({
        url: '/ajaxGetMessage?type=old&id='+$('.hermesName').text()+'&pos='+last,
        before: function(){},
        success: pullUpAction,
        complete: function(){},
        error: function(){}
    });
}

function getNew() {
    pullDownEl.className = 'loading';
    pullDownEl.querySelector('.pullDownLabel').innerHTML = '加载中...';	

    sendAjaxRequest({
        url: '/ajaxGetMessage?type=new&id=' + $('.hermesName').text(),
        before: function(){},
        success: pullDownAction,
        complete: function(){},
        error: function(){}
    });
}

function cancelSub( hermes ) {
    var tmp = hermes.split(/\./);
    if (tmp.length < 2) { return;}

    var hms = tmp[0];
    var item = hermes.substring(hms.length+1, hermes.length);
 
    sendAjaxRequest({ 
        url: '/ajaxBookSubscribe?hermesID=' + hms + '&' + item + '=0',
        before: showLoader,
        success: responseCancel,
        complete: hideLoader,
        error: ajax_error });
}

function responseCancel(data) {
   if ( data.response === 1 ) { 
       popOver('Sorry，稍后再试下嘛！'); 
   } else if ( data.response === 0 || data.response === 3) { 
       $('#contentList1').find('li').removeClass('gary').addClass('gary');
       $('#cancelBtn').attr('disabled', 'true').text('取消成功');
       popOver('取消订阅成功了yeah～'); 
   } 
}

function filter(event) {
    var $btn = $(event.target);
    var numPrd; 
    var hermes;

    if ( $btn.attr('id') === 'single' ) {
        numPrd = $btn.parents('.webui-popover-content').find('#stopPrd').val();
    } else if ( $btn.attr('id') === 'group' ) {
        var $popover = $btn.parents('.webui-popover-content');
        numPrd = $popover.find('#stopPrdGrp').val();
        hermes = $.trim($popover.find('#hermesString').val());
        if ( hermes.length == 0 ) { 
            popOver('请设置机器群组信息');
            return false; 
        } 
    }

    if ( numPrd.length == 0 || numPrd === '0 天, 00:00:00' ) { 
        popOver('请设置屏蔽时间');
        return false; 
    }

    var strings = numPrd.split(',');
    var tmp = strings[0].split(' ');
    var time = parseInt(tmp[0]) * 24 * 3600;
        
    tmp = strings[1].split(':');
    time += parseInt(tmp[0]) * 3600 + parseInt(tmp[1]) * 60 + parseInt(tmp[2]);

    var hName = $('.hermesName').text();

    if ( $btn.attr('id') === 'single' ) {
        sendAjaxRequest({
            url: '/ajaxSetFilterMessage?name='+hName+'&node='+$target.find('.node').text()+'&time='+time,
            before: function(){},
            complete: function(){},
            error: function(){},
            success: function(data){
                if ( data.response == 0 && $target) {
                    $target.removeClass('green').addClass('green');
                }

                popOver('屏蔽成功了yeah~!');
            } 
        });
    } else if ( $btn.attr('id') === 'group' ) {
        sendAjaxRequest({
            url: '/ajaxGetNodes?name='+hName+'&hms='+hermes+'&time='+time,
            before: function(){},
            complete: function(){},
            error: function(){},
            success: function( data ){
                if ( data.nodes == 1 ) {
                    popOver('屏蔽失败!');
                } else if ( data.nodes == 2 ) {
                    popOver('一次不能超过20台机器!');
                } else if ( data.nodes == 3 ) {
                    popOver('机器格式不合法!');
                } else {
                    popConfirmation(data);
                } 
            } 
        });
    }
}

