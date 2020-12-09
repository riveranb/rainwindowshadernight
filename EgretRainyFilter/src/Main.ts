//////////////////////////////////////////////////////////////////////////////////////
//
//  Copyright (c) 2014-present, Egret Technology.
//  All rights reserved.
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the Egret nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY EGRET AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
//  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL EGRET AND CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;LOSS OF USE, DATA,
//  OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
//  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//////////////////////////////////////////////////////////////////////////////////////

class Main extends eui.UILayer
{
    private _lastTime: number;
    private _touchX: number;
    private _touchY: number;
    private _raindropFilter: egret.CustomFilter;

    protected createChildren(): void
    {
        super.createChildren();

        egret.lifecycle.onPause = () => egret.ticker.pause();

        egret.lifecycle.onResume = () => egret.ticker.resume();

        //inject the custom material parser
        //注入自定义的素材解析器
        let assetAdapter = new AssetAdapter();
        egret.registerImplementation("eui.IAssetAdapter", assetAdapter);

        this.runGame();
    }

    private async runGame()
    {
        await this.loadResource()
        this.createGameScene();
    }

    private async loadResource()
    {
        try
        {
            const loadingView = new LoadingUI();
            this.stage.addChild(loadingView);
            await RES.loadConfig("resource/default.res.json", "resource/");
            await this.loadTheme();
            await RES.loadGroup("preload", 0, loadingView);
            this.stage.removeChild(loadingView);
        }
        catch (e)
        {
            console.error(e);
        }
    }

    private loadTheme()
    {
        return new Promise((resolve, reject) =>
            {
                // load skin theme configuration file, you can manually modify the file. And replace the default skin.
                //加载皮肤主题配置文件,可以手动修改这个文件。替换默认皮肤。
                let theme = new eui.Theme("resource/default.thm.json", this.stage);
                theme.addEventListener(eui.UIEvent.COMPLETE, () => resolve(), this);

            })
    }
    
    /**
     * 创建场景界面
     * Create scene interface
     */
    protected createGameScene(): void
    {
        let sky = this.createBitmapByName("bg_jpg");
        this.addChild(sky);
        let stageW = this.stage.stageWidth;
        let stageH = this.stage.stageHeight;
        sky.width = stageW;
        sky.height = stageH;

        let vertexSh: string = RES.getRes("vertex_shader");
        let fragmentSh: string = RES.getRes("fragment_shader");
        this._raindropFilter = new egret.CustomFilter(
            vertexSh,
            fragmentSh,
            {
                _Time: 0,
                _GridSize: 5,
                _Blur: 1.5,
                _Distort: 2.5,
            });

        sky.filters = [this._raindropFilter];
        
        this.addEventListener(egret.Event.ENTER_FRAME, () =>
            {
                let currentTime = egret.getTimer() * 0.001;
                if (this._lastTime == 0)
                {
                    this._lastTime = currentTime;
                }

                let delta = currentTime - this._lastTime;
                // TODO: not work? why?
                //this._raindropFilter.uniforms._Time += delta;
                this._raindropFilter.uniforms._Time += 0.005;

                this._lastTime = currentTime;
            },
            this);

        this.addEventListener(egret.TouchEvent.TOUCH_BEGIN, (e:egret.TouchEvent) =>
            {
                this._touchX = e.stageX;
                this._touchY = e.stageY;
                this.addEventListener(egret.TouchEvent.TOUCH_MOVE, this.onTouchMove, this);
            },
            this);

        let info = new egret.TextField();
        info.y = 100;
        info.width = stageW;
        info.textAlign = egret.HorizontalAlign.CENTER;
        info.text = "Drag mouse left button:\n" + 
            "Horizontally to adjust dense/size of droplets\n" +
            "Vertically to adjust humidity blur";
        this.addChild(info);
    }

    /**
     * 根据name关键字创建一个Bitmap对象。name属性请参考resources/resource.json配置文件的内容。
     * Create a Bitmap object according to name keyword.As for the property of name please refer to the configuration file of resources/resource.json.
     */
    private createBitmapByName(name: string): egret.Bitmap 
    {
        let result = new egret.Bitmap();
        let texture: egret.Texture = RES.getRes(name);
        result.texture = texture;
        return result;
    }

    private onTouchMove(e:egret.TouchEvent): void
    {
        let deltaX = e.stageX - this._touchX;
        let deltaY = e.stageY - this._touchY;
        this._touchX = e.stageX;
        this._touchY = e.stageY;

        this._raindropFilter.uniforms._GridSize += deltaX * 0.025;
        this._raindropFilter.uniforms._Distort += deltaY * 0.025;
        this._raindropFilter.uniforms._Blur += deltaY * 0.001;

        this._raindropFilter.uniforms._GridSize = this.Clamp(this._raindropFilter.uniforms._GridSize, 2, 20);
        this._raindropFilter.uniforms._Distort = this.Clamp(this._raindropFilter.uniforms._Distort, -5, 5);
        this._raindropFilter.uniforms._Blur = this.Clamp(this._raindropFilter.uniforms._Blur, 0.02, 1);

        this.once(egret.TouchEvent.TOUCH_END, (e:egret.TouchEvent) =>
            {
                this.removeEventListener(egret.TouchEvent.TOUCH_MOVE, this.onTouchMove, this);
            },
            this);
    }

    private Clamp(a:number, min:number, max:number): number
    {
        a = Math.min(a, max);
        a = Math.max(a, min);
        return a;
    }
}
