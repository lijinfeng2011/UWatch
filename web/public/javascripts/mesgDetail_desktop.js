var pullUpEl   = document.getElementById('pullUp'),
    pullDownEl = document.getElementById('pullDown'),
    $mesgList  = $('#contentList1'),
    $filterRow = null;

$(document).on('pagebeforeshow', '#mesgDetail', function() {
    if (sessionStorage.getItem('glanceView') == 'oncall') {
        $('#cancelBtn').attr('disabled', 'true');
    }
});

function pullUpAction ( data ) {
    setTimeout(function () {
        var content = '', count = 0;
        $.each( data.response, function( n, mesg ) {
            count++;
            content = content + '<li class="gary"><button data-role="none" class="filterBtn" disabled="disabled">屏蔽1小时</button><span class="index hide">';
            content = content + mesg.idx;
            content = content + '</span><span class="node hide">';
            content = content + mesg.node;
            content = content + '</span> ';
            content = content + mesg.content;
            content = content + '</li>';
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
    setTimeout( function () {
        var content = '', count = 0;
        $.each( data.response, function( n, mesg ) {
            count++;
            content = content + '<li data-swipeurl="#"><button data-role="none" class="filterBtn" onclick="filter(event)">屏蔽1小时</button><span class="index hide">';
            content = content + mesg.idx;
            content = content + '</span><span class="node hide">';
            content = content + mesg.node;
            content = content + '</span> ';
            content = content + mesg.content;
            content = content + '</li>';
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
    $filterRow = $(event.target).closest('li');
    var node = $filterRow.find('.node').text();

    sendAjaxRequest({
        url: '/ajaxSetFilterMessage?name=' + $('.hermesName').text() + '&node=' + node,
        before: function(){},
        complete: function(){},
        error: function(){},
        success: updateFilter });
}

function updateFilter( data ) {
    if ( data.response == 0 && $filterRow) {
        $filterRow.removeClass('green').addClass('green');
    }

    $filterRow = null;    
}
