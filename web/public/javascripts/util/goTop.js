GoTop = function() {
    this.config = {
        pageWidth: 960,
        topNodeId: 'go-top',
        smtNodeId: 'smt-form',
        nodeWidth: 50,
        distanceToBottom: 120,
        distanceToPage: 20,
        hideRegionHeight: 90,
        zIndex: 100,
        text: ''
    };

    this.cache = {
        topLinkThread: null,
        openedForm: null,
    }
};

GoTop.prototype = {
    init: function(config) {
            this.config = config || this.config;
            var _self = this;

            $(window).on('scrollstop', function(){
                _self._scrollScreen( { _self: _self} );
            });

            $(window).on('resize', function() {
                _self._resizeWindow( { _self: _self } );
            });

            _self._insertNode( {_self:_self} );
    },

    _insertNode: function(args) {
            var _self = args._self;

            var topLink = $('<a id="' + _self.config.topNodeId + '" href="#">' + _self.config.text + '</a>');
            var smtLink = $('<a id="' + _self.config.smtNodeId + '" href="#">' + _self.config.text + '</a>');
            topLink.click( function() {
                $('html,body').animate({scrollTop: 0}, 200);
                return false;
            }).appendTo($('body'));

            smtLink.click( function() {
                submitSubForm( _self.cache.openedForm );
                return false;
            }).appendTo($('body'));

            var right = _self._getDistanceToBottom({_self:_self});

            // IE6 (不支持 position:fixed) 的样式
            if(/MSIE 6/i.test(navigator.userAgent)) {
                topLink.css({
                    'display': 'none',
                    'position': 'absolute',
                    'right': right + 'px'
                });
                smtLink.css({
                    'display': 'none',
                    'position': 'absolute',
                    'right': right + 'px'
                });
            } else {
                topLink.css({
                    'display': 'none',
                    'position': 'fixed',
                    'right': right + 'px',
                    'top': ($(window).height() - _self.config.distanceToBottom) + 'px',
                    'z-index': _self.config.zIndex
                });
                smtLink.css({
                    'display': 'none',
                    'position': 'fixed',
                    'right': right + 'px',
                    'top': ($(window).height() - _self.config.distanceToBottom + 40) + 'px',
                    'z-index': _self.config.zIndex
                });
            }
    },

    _scrollScreen: function(args) {
            var _self = args._self;
       
            // 当节点进入隐藏区域, 隐藏节点
            var topLink = $('#' + _self.config.topNodeId);
            if ($(document).scrollTop() <= _self.config.hideRegionHeight) {
                clearTimeout(_self.cache.topLinkThread);
                topLink.hide();
                return;
            }

            if (/MSIE 6/i.test(navigator.userAgent)) {
                clearTimeout(_self.cache.topLinkThread);
                topLink.hide();
 
                _self.cache.topLinkThread = setTimeout(function() {
                    var top = $(document).scrollTop() + $(window).height() - _self.config.distanceToBottom;
                    topLink.css({'top': top + 'px'}).fadeIn();
                }, 200);
            } else {
                topLink.fadeIn();
            }
    },

    _resizeWindow: function(args) {
            var _self = args._self;

            var topLink = $('#' + _self.config.topNodeId);
            var smtLink = $('#' + _self.config.smtNodeId);

            var right = _self._getDistanceToBottom({_self:_self});
            var top = $(window).height() - _self.config.distanceToBottom;

            if (/MSIE 6/i.test(navigator.userAgent)) {
                top += $(document).scrollTop();
            }

            topLink.css({
                'right': right + 'px',
                'top': top + 'px'
            });
            smtLink.css({
                'right': right + 'px',
                'top': top + 40 + 'px'
            });
    },

    _getDistanceToBottom: function(args) {
           var _self = args._self;
           var right = parseInt(($(window).width() - _self.config.pageWidth + 1)/2 - _self.config.nodeWidth - _self.config.distanceToPage, 10);
           if (right < 10) {
               right = 10;
           }

           return right;
    },

    openSMT: function(args) {
        this.cache.openedForm = args;
        if(!$('#smt-form').is(':visible')) { $('#smt-form').show();}
    },

    closeSMT: function() {
        this.cache.openedForm = null;
        if ($('#smt-form').is(':visible')) { $('#smt-form').hide();}
    }
};
