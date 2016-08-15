<?php
    function createCaptcha( $code ) {
	$width  = 140;
	$height = 40;
	$length	= 4;
	$font   = __DIR__ . '/msyhbd.ttf';

        $res = imagecreatetruecolor( $width, $height );

        $bgColor = imagecolorallocate( $res, mt_rand(130,255), mt_rand(130,255), mt_rand(130,255) );

        imagefilledrectangle($res, 0, 0, $width, $height, $bgColor);

        for( $i=0; $i<$length; $i++ ) {
            $fontColor = imagecolorallocate($res,mt_rand(0,120),mt_rand(0,120),mt_rand(0,120));
            imagettftext($res,mt_rand(24,28),mt_rand(-30,30),$i*$width/$length,mt_rand(20,40),$fontColor,$font,$code[$i]);
	}

        for( $i=0; $i<200; $i++) {
            $fontColor = imagecolorallocate($res,mt_rand(0,120),mt_rand(0,120),mt_rand(0,120));
            imagesetpixel($res,mt_rand(0,$width),mt_rand(0,$height),$fontColor);
        }

        for( $i=0; $i<5; $i++) {
            $fontColor = imagecolorallocate($res,mt_rand(0,120),mt_rand(0,120),mt_rand(0,120));
            imageline($res,mt_rand(0,$width),mt_rand(0,$height),mt_rand(0,$width),mt_rand(0,$height),$fontColor);
        }

        //header("content-type:image/png");

        return imagepng( $res );

        //imagedestroy($res);
    }

    createCaptcha( $argv[1] );
?>
