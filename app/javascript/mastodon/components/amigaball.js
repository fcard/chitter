import React from 'react';

class AmigaBall extends React.Component {

  static defaultProps = {
    size: 18,
  };


  constructor(props){
    super(props);
    this.bail=false;
    this.activated=this.props.active?1:0;
    this.offset = Math.random() * Math.PI/2;
    let tempButton = document.createElement('div');
    tempButton.classList.add('icon-button');
    tempButton.classList.add('horrible-hack');
    tempButton.style.display = 'none';
    document.body.appendChild(tempButton);
    this.inactiveColor = getComputedStyle(tempButton).color;
    this.inverted = getComputedStyle(tempButton).content == '"yes"';
    document.body.removeChild(tempButton);
  }
  componentDidMount(){
    this.frame(0)
  }
  frame(t) {
    if(this.bail) return;

    if(t==0 || this.activated >= 0.001){
      this.draw();
    }

    if(this.props.active){
      this.activated += (1 - this.activated) * 0.03
      if (this.activated > 0.999){
        this.activated = 1;
      }
    }
    else {
      this.activated *= 0.91;
      if (this.activated < 0.001){
        this.activated = 0;
      }
    }

    this.offset += 0.06 * this.activated;
    this.offset = this.offset % (Math.PI/2);

    window.requestAnimationFrame(this.frame.bind(this))
  }
  draw(){
    let ctx = this.refs.canvas.getContext("2d");
    const width = this.refs.canvas.width;
    const height = this.refs.canvas.height;
    const padding = width/9;
    let primary_color = 'white';
    let secondary_color = 'red';
    if(this.inverted){
      let a = primary_color;
      primary_color = secondary_color;
      secondary_color = a;
    }
    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = secondary_color;
    ctx.globalAlpha = this.activated;
    ctx.beginPath();
    ctx.arc(width/2, height/2, width/2-padding-0.5, 0, 2 * Math.PI);
    ctx.fill();

    function drawCheckerboard(fillStyle, alpha){
      // default inactive button color: hsl(225, 16%, 45%)
      ctx.globalAlpha = alpha;
      ctx.fillStyle = fillStyle;
      ctx.beginPath();
      ctx.moveTo(width/2, padding);
      function go(theta,phi){
          phi -= this.offset;
          phi = Math.max(-Math.PI/2, phi);
          phi = Math.min(Math.PI/2, phi);
          let x = Math.sin(theta) * Math.sin(phi) * (width - 2*padding)/2 + width/2;
          let y = -Math.cos(theta) * (height - 2*padding)/2 + height/2;
          ctx.lineTo(x, y);
      }
      go = go.bind(this);

      // vertical stripe 1
      for(let theta = 0; theta <= Math.PI; theta+=Math.PI/6){
          let phi = -Math.PI/2;
          go(theta, phi);
      }
      for(let theta = Math.PI; theta >= 0; theta-=Math.PI/6){
          let phi = -Math.PI/4;
          go(theta, phi);
      }

      // vertical stripe 2
      for(let theta = 0; theta <= Math.PI; theta+=Math.PI/6){
          let phi = 0;
          go(theta, phi);
      }
      for(let theta = Math.PI; theta >= 0; theta-=Math.PI/6){
          let phi = Math.PI/4;
          go(theta, phi);
      }

      // vertical stripe 3
      for(let theta = 0; theta <= Math.PI; theta+=Math.PI/6){
          let phi = Math.PI/2;
          go(theta, phi);
      }
      for(let theta = Math.PI; theta >= 0; theta-=Math.PI/6){
          let phi = 3*Math.PI/4;
          go(theta, phi);
      }

      for(let tetha = 0; tetha <= 3*Math.PI/4; tetha += Math.PI/8){
          let phi = Math.PI;
          go(tetha, phi);
      }

      go(3*Math.PI/4, -Math.PI/2);
      go(Math.PI/2, -Math.PI/2);
      go(Math.PI/2, Math.PI);
      go(Math.PI/4, Math.PI);
      go(Math.PI/4, -Math.PI/2);

      ctx.closePath();
      ctx.fill();
      ctx.globalAlpha = 1;
    }
    drawCheckerboard = drawCheckerboard.bind(this);
    drawCheckerboard(this.inactiveColor, 1);
    drawCheckerboard(primary_color, this.activated);

  }

  componentWillUnmount(){
    this.bail = true;
  }
  render() {
    return <canvas ref="canvas"
      className={this.props.className}
      width={this.props.size * 1.28571429}
      height={this.props.size * 1.28571429}
      onClick={this.props.onClick}
      aria-label={this.props.title}
      title={this.props.title}
      style={{ cursor: "pointer", transform: "rotate(20deg)" }}
    />;
  }
}

export default AmigaBall;
