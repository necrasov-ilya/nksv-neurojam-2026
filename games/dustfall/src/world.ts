import * as T from 'three';

export function createWorld(scene: T.Scene) {
  const solids: T.Object3D[] = [];
  const colliders: {x:number;z:number;hx:number;hz:number;height:number}[] = [];
  const containers: {id:number;position:T.Vector3;mesh:T.Group;tier:number;opened:boolean}[] = [];
  const zones = [{name:'SCRAP YARD',x:-65,z:70},{name:'RELAY STATION',x:-95,z:-65},{name:'FLOODED DEPOT',x:80,z:-45},{name:'EXTRACTION RIDGE',x:10,z:-160}];
  let seed=7219; const rand=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
  const smooth=(v:number)=>{v=T.MathUtils.clamp(v,0,1);return v*v*(3-2*v);};
  const height=(x:number,z:number)=>7*smooth((-z-80)/100)*(.48+.52*smooth((45-x)/95)) + 2.6*Math.exp(-((x+155)**2/1600+(z+10)**2/17000));
  const N=110,step=4, heights=new Float32Array((N+1)*(N+1));
  for(let j=0;j<=N;j++)for(let i=0;i<=N;i++)heights[j*(N+1)+i]=height(i*step-220,j*step-220);
  function groundHeight(x:number,z:number){const gx=T.MathUtils.clamp((x+220)/step,0,N-.0001),gz=T.MathUtils.clamp((z+220)/step,0,N-.0001),i=Math.floor(gx),j=Math.floor(gz),u=gx-i,v=gz-j,a=heights[j*(N+1)+i],b=heights[j*(N+1)+i+1],c=heights[(j+1)*(N+1)+i],d=heights[(j+1)*(N+1)+i+1];return u+v<=1?a+(b-a)*u+(c-a)*v:d+(c-d)*(1-u)+(b-d)*(1-v);}
  function texture(base:string,kind='steel') {const c=document.createElement('canvas');c.width=c.height=256;const g=c.getContext('2d')!;g.fillStyle=base;g.fillRect(0,0,256,256);for(let i=0;i<4200;i++){g.fillStyle=`rgba(${rand()>.5?'235,224,188':'31,36,30'},${rand()*.15})`;g.fillRect(rand()*256,rand()*256,rand()*4+1,kind==='steel'?rand()*20:rand()*4);}if(kind==='steel')for(let x=0;x<256;x+=16){g.fillStyle='rgba(15,25,22,.2)';g.fillRect(x,0,3,256);g.fillStyle='rgba(255,244,219,.12)';g.fillRect(x+3,0,2,256);}const t=new T.CanvasTexture(c);t.colorSpace=T.SRGBColorSpace;t.wrapS=t.wrapT=T.RepeatWrapping;return t;}
  const steelMap=texture('#879080'),rustMap=texture('#91644c'),earthMap=texture('#b8b8a4','earth');earthMap.repeat.set(100,100);
  const mat=(color:number,map?:T.Texture)=>new T.MeshStandardMaterial({color,map,roughness:.88,metalness:map===steelMap?.35:.08});
  const m={steel:mat(0x929b8d,steelMap),rust:mat(0xb58562,rustMap),dark:mat(0x333f3c),concrete:mat(0xa1a48f),sage:mat(0x657864),sand:mat(0xaaa184),black:mat(0x242b28),leaf:mat(0x526747),leaf2:mat(0x73805b),bark:mat(0x615747),rock:mat(0x818677),glass:new T.MeshStandardMaterial({color:0x506e6e,roughness:.24,metalness:.5}),light:new T.MeshBasicMaterial({color:0xffd28a})};
  const batches=new Map<string,{g:T.BufferGeometry;m:T.Material;matrices:T.Matrix4[];solid:boolean}>();
  const cube=new T.BoxGeometry(1,1,1),cylinder=new T.CylinderGeometry(1,1,1,12),rockGeo=new T.IcosahedronGeometry(1,1),leafGeo=new T.IcosahedronGeometry(1,1),dummy=new T.Object3D();
  function batch(key:string,g:T.BufferGeometry,material:T.Material,x:number,y:number,z:number,sx:number,sy:number,sz:number,rotation=0,solid=false){let b=batches.get(key);if(!b){b={g,m:material,matrices:[],solid};batches.set(key,b);}dummy.position.set(x,y,z);dummy.rotation.set(0,rotation,0);dummy.scale.set(sx,sy,sz);dummy.updateMatrix();b.matrices.push(dummy.matrix.clone());}
  function box(x:number,y:number,z:number,w:number,h:number,d:number,material:T.Material=m.steel,blocking=false){batch('box'+material.uuid,cube,material,x,y,z,w,h,d,0,true);if(blocking)colliders.push({x,z,hx:w/2,hz:d/2,height:y+h/2-groundHeight(x,z)});}
  function cyl(x:number,y:number,z:number,r:number,h:number,material:T.Material=m.steel){batch('cyl'+material.uuid,cylinder,material,x,y,z,r,h,r,0,true);}
  function beam(a:T.Vector3,b:T.Vector3,width:number,material:T.Material=m.dark){const mid=a.clone().add(b).multiplyScalar(.5);dummy.position.copy(mid);dummy.quaternion.setFromUnitVectors(new T.Vector3(0,1,0),b.clone().sub(a).normalize());dummy.scale.set(width,a.distanceTo(b),width);dummy.updateMatrix();const key='beam'+material.uuid;let v=batches.get(key);if(!v){v={g:cube,m:material,matrices:[],solid:false};batches.set(key,v);}v.matrices.push(dummy.matrix.clone());}
  const v=(x:number,y:number,z:number)=>new T.Vector3(x,y,z);
  function mesh(g:T.BufferGeometry,material:T.Material,x:number,y:number,z:number,solid=false){const o=new T.Mesh(g,material);o.position.set(x,y,z);o.castShadow=true;o.receiveShadow=true;scene.add(o);if(solid)solids.push(o);return o;}
  const meadowDark=new T.Color(0x687864),meadowLight=new T.Color(0x909579),dryEarth=new T.Color(0xa0947c),groundTint=new T.Color();
  const groundColor=(x:number,z:number)=>{
    const meadow=.5+.25*Math.sin(x*.043+Math.sin(z*.026)*2)+.25*Math.cos(z*.057-x*.018);
    const dry=.5+.5*Math.sin(x*.019+z*.025+Math.sin(z*.071));
    return groundTint.copy(meadowDark).lerp(meadowLight,meadow).lerp(dryEarth,dry*.32);
  };
  const terrain=new T.PlaneGeometry(440,440,N,N);terrain.rotateX(-Math.PI/2);
  const pos=terrain.attributes.position,colors=new Float32Array(pos.count*3);
  for(let i=0;i<pos.count;i++){const x=pos.getX(i),z=pos.getZ(i);pos.setY(i,groundHeight(x,z));groundColor(x,z).toArray(colors,i*3);}
  terrain.setAttribute('color',new T.BufferAttribute(colors,3));terrain.computeVertexNormals();
  const terrainMaterial = new T.MeshStandardMaterial({map:earthMap,vertexColors:true,roughness:1});
  mesh(terrain,terrainMaterial,0,0,0,true);
  scene.background=new T.Color(0xb9c5c3);scene.fog=new T.FogExp2(0xb9c5c3,.0027);
  const skyMaterial=new T.ShaderMaterial({
    side:T.BackSide,depthWrite:false,depthTest:false,toneMapped:false,
    uniforms:{time:{value:0},sunDirection:{value:v(-45,80,40).normalize()},top:{value:new T.Color(0x628fac)},horizon:{value:new T.Color(0xe4d8bd)},haze:{value:new T.Color(0xb9c5c3)}},
    vertexShader:`varying vec3 direction;
      void main(){direction=position;vec4 clip=projectionMatrix*vec4(mat3(viewMatrix)*position,1.0);gl_Position=clip.xyww;}`,
    fragmentShader:`varying vec3 direction;uniform float time;uniform vec3 sunDirection;uniform vec3 top;uniform vec3 horizon;uniform vec3 haze;
      float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
      float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
      float cloud(vec2 p){return noise(p)*.54+noise(p*2.03+7.1)*.28+noise(p*4.09+13.7)*.13+noise(p*8.17)*.05;}
      void main(){
        vec3 d=normalize(direction);float elevation=max(d.y,0.0);
        vec3 color=mix(horizon,top,smoothstep(0.0,.78,elevation));
        color=mix(haze,color,smoothstep(-.07,.035,d.y));
        float sun=max(dot(d,sunDirection),0.0);
        color+=vec3(1.0,.66,.32)*pow(sun,12.0)*.16;
        color+=vec3(1.0,.77,.43)*pow(sun,220.0)*.44;
        color=mix(color,vec3(1.0,.95,.78),smoothstep(.99965,.99986,sun));
        vec2 plane=d.xz/(elevation+.22);
        vec2 drift=vec2(time*.003,time*.0012);
        float lower=cloud(plane*vec2(2.1,5.3)+drift);
        float upper=cloud(plane*vec2(4.6,12.0)-drift*.65+19.0);
        float wisps=smoothstep(.47,.73,lower)*.58+smoothstep(.57,.78,upper)*.3;
        wisps*=smoothstep(.025,.2,d.y);
        vec3 cloudColor=mix(vec3(.69,.76,.79),vec3(1.0,.94,.82),.55+.45*sun);
        color=mix(color,cloudColor,clamp(wisps,0.0,.8));
        gl_FragColor=vec4(color,1.0);
        #include <colorspace_fragment>
      }`,
  });
  // Camera-relative, far-depth sky cannot clip against the world's far plane or cast a giant shadow.
  const sky=new T.Mesh(new T.SphereGeometry(1,32,16),skyMaterial);sky.frustumCulled=false;sky.renderOrder=-100;scene.add(sky);
  const roadSamples:{x:number;z:number;width:number}[]=[];
  const roadCanvas=document.createElement('canvas');roadCanvas.width=roadCanvas.height=2048;
  const roadPaint=roadCanvas.getContext('2d')!;
  roadPaint.fillStyle='black';roadPaint.fillRect(0,0,2048,2048);
  roadPaint.lineCap=roadPaint.lineJoin='round';
  function road(points:number[][],width:number){
    const curve=new T.CatmullRomCurve3(points.map(p=>v(p[0],0,p[1]))),segments=Math.ceil(curve.getLength());
    roadPaint.beginPath();
    for(let i=0;i<=segments;i++){
      const p=curve.getPointAt(i/segments);
      roadSamples.push({x:p.x,z:p.z,width:width/2+1.5});
      const x=(p.x+220)/440*2048,y=(p.z+220)/440*2048;
      if(i===0)roadPaint.moveTo(x,y);else roadPaint.lineTo(x,y);
    }
    roadPaint.strokeStyle='white';roadPaint.lineWidth=width/440*2048;roadPaint.stroke();
  }
  road([[0,154],[-15,118],[-55,103],[-83,98],[-105,66],[-122,12],[-111,-53],[-70,-111],[-40,-160]],8);
  road([[0,145],[29,105],[52,52],[91,8],[111,-46],[80,-105],[65,-165]],8);
  road([[0,137],[4,94],[-13,45],[12,5],[-8,-43],[12,-90],[6,-137],[25,-173]],6);
  road([[-105,60],[-105,32],[-24,30],[39,28],[100,-10]],5);road([[-115,-55],[-48,-78],[22,-64],[94,-58]],5);
  road([[-83,98],[-79,87],[-79,78]],3);road([[-111,-53],[-103,-70],[-100,-82]],3);road([[91,8],[80,-15],[79,-38]],3);
  const roadMask=new T.CanvasTexture(roadCanvas);roadMask.flipY=false;
  terrainMaterial.onBeforeCompile=shader=>{
    shader.uniforms.roadMask={value:roadMask};
    shader.vertexShader='varying vec2 roadUV;\n'+shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nroadUV=(position.xz+220.0)/440.0;');
    shader.fragmentShader='uniform sampler2D roadMask; varying vec2 roadUV;\n'+shader.fragmentShader.replace('#include <color_fragment>','#include <color_fragment>\nfloat road=texture2D(roadMask,roadUV).r;diffuseColor.rgb=mix(diffuseColor.rgb,vec3(.36,.31,.23),road*.85);');
  };
  const onRoad=(x:number,z:number,margin=0)=>roadSamples.some(p=>(x-p.x)**2+(z-p.z)**2<(p.width+margin)**2);
  function sign(text:string,x:number,z:number,w=8){const c=document.createElement('canvas');c.width=512;c.height=128;const ctx=c.getContext('2d')!;ctx.fillStyle='#34433d';ctx.fillRect(0,0,512,128);ctx.strokeStyle='#c3ba90';ctx.lineWidth=7;ctx.strokeRect(10,10,492,108);ctx.fillStyle='#ddd2ae';ctx.font='bold 35px monospace';ctx.textAlign='center';ctx.fillText(text,256,77);const tex=new T.CanvasTexture(c);tex.colorSpace=T.SRGBColorSpace;const y=groundHeight(x,z);mesh(new T.BoxGeometry(w,2,.15),new T.MeshStandardMaterial({map:tex,roughness:.85}),x,y+4,z);for(const dx of [-w*.4,w*.4])box(x+dx,y+2,z,.15,4,.15,m.dark);}
  function shipping(x:number,z:number,w=12,material:T.Material=m.rust){const y=groundHeight(x,z);box(x,y+1.7,z,w,3.4,3.6,material,true);for(const dx of [-w/2,w/2])for(const dz of [-1.8,1.8])box(x+dx,y+1.7,z+dz,.16,3.55,.16,m.dark);for(const dy of [.1,3.35])box(x,y+dy,z+1.86,w,.13,.1,m.sand);for(const dx of [-.45,.45])box(x+dx,y+1.7,z+1.88,.06,2.8,.07,m.dark);}
  for(const p of [[-80,85],[-57,91],[-93,68],[-45,62],[-89,46],[-58,42],[56,-24],[75,-22],[108,-72],[71,-79]])shipping(p[0],p[1],12,rand()>.5?m.rust:m.steel);
  shipping(-80,85,12,m.steel);sign('04 / SALVAGE WORKS',-70,106);sign('RELAY  /  NORTH ARRAY',-109,-32);sign('PUMPING DEPOT  /  02',85,14);
  function tank(x:number,z:number,r=5,h=12){const y=groundHeight(x,z);cyl(x,y+h/2,z,r,h,m.steel);cyl(x,y+.3,z,r+1,.6,m.concrete);const roof=mesh(new T.ConeGeometry(r,.9,24),m.dark,x,y+h+.4,z,true);roof.receiveShadow=true;for(const yy of [h*.35,h*.8]){const ring=mesh(new T.TorusGeometry(r+.3,.12,5,32),m.sand,x,y+yy,z);ring.rotation.x=Math.PI/2;}for(let i=0;i<12;i++){const a=i*Math.PI/6;cyl(x+Math.cos(a)*(r+.4),y+h*.8+.5,z+Math.sin(a)*(r+.4),.045,1,m.dark);}colliders.push({x,z,hx:r,hz:r,height:h});}
  tank(119,-32);tank(134,-47,6,15);tank(120,-66,4,10);tank(-124,-70,3,8);
  function warehouse(x:number,z:number,w:number,d:number){const y=groundHeight(x,z);box(x,y+.1,z,w,.2,d,m.concrete);for(const dx of [-w/2,w/2])for(const dz of [-d/2,0,d/2]){box(x+dx,y+4,z+dz,.4,8,.4,m.dark,true);}box(x,y+3.4,z-d/2,w,6.8,.35,m.steel,true);for(const dx of [-w*.34,w*.34]){box(x+dx,y+2.5,z+d/2,w*.3,5,.35,m.steel,true);box(x+dx,y+5.9,z+d/2,w*.25,1.1,.4,m.glass);}for(const dx of [-w/2,w/2]){box(x+dx,y+2.3,z,.3,4.6,d,m.steel,true);for(let k=-1;k<=1;k++)box(x+dx,y+5.5,z+k*d/3,.32,1.5,d*.25,m.glass);}for(const dz of [-d/2,0,d/2]){beam(v(x-w/2,y+7,z+dz),v(x,y+9.8,z+dz),.2);beam(v(x,y+9.8,z+dz),v(x+w/2,y+7,z+dz),.2);}const roof=mesh(new T.BoxGeometry(w*.52,.15,d),m.rust,x-w*.25,y+8.4,z,true);roof.rotation.z=.27;const broken=mesh(new T.BoxGeometry(w*.5,.15,d*.32),m.steel,x+w*.25,y+8.4,z-d*.34,true);broken.rotation.z=-.27;}
  warehouse(-69,61,22,18);warehouse(79,-52,24,22);
  function cooling(x:number,z:number){const y=groundHeight(x,z);const points=[v(12,0,0),v(10,7,0),v(7,22,0),v(7.4,31,0),v(8.3,37,0)].map(p=>new T.Vector2(p.x,p.y));mesh(new T.LatheGeometry(points,40),m.concrete,x,y+3,z,true);for(let i=0;i<12;i++){const a=i*Math.PI/6;beam(v(x+Math.cos(a)*11,y,z+Math.sin(a)*11),v(x+Math.cos(a+.1)*11,y+6,z+Math.sin(a+.1)*11),.8,m.concrete);}for(const yy of [4,39.8]){const ring=mesh(new T.TorusGeometry(yy===4?11.8:8.4,.35,6,48),m.sand,x,y+yy,z);ring.rotation.x=Math.PI/2;}const dark=mesh(new T.CircleGeometry(7.7,40),m.dark,x,y+37.4,z);dark.rotation.x=-Math.PI/2;colliders.push({x,z,hx:10,hz:10,height:40});}
  cooling(150,37);cooling(180,12);
  function crane(x:number,z:number){const y=groundHeight(x,z);for(const dx of [-2,2])for(const dz of [-2,2])box(x+dx,y+12,z+dz,.3,24,.3,m.rust,true);for(let k=0;k<6;k++){const a=y+k*4;beam(v(x-2,a,z-2),v(x+2,a+4,z-2),.13,m.sand);beam(v(x+2,a,z+2),v(x-2,a+4,z+2),.13,m.sand);}box(x+8,y+24,z,31,.4,2,m.rust);for(let i=-6;i<23;i+=3){beam(v(x+i,y+24,z),v(x+i+3,y+26,z),.15,m.sand);beam(v(x+i,y+26,z),v(x+i+3,y+24,z),.15,m.sand);}beam(v(x-4,y+24,z),v(x,y+31,z),.09);beam(v(x,y+31,z),v(x+23,y+24,z),.09);beam(v(x+18,y+24,z),v(x+18,y+8,z),.045);box(x+18,y+7.5,z,.7,1,.5,m.dark);box(x-6,y+23,z,4,3,3,m.dark);}
  crane(-101,87);crane(109,-5);
  const antennaY=groundHeight(-100,-82);for(const dx of [-2,2])for(const dz of [-2,2])beam(v(-100+dx,antennaY,-82+dz),v(-100+dx*.25,antennaY+30,-82+dz*.25),.22,m.steel);for(let k=0;k<7;k++){const y=antennaY+k*4;beam(v(-102,y,-84),v(-98,y+4,-84),.14,m.steel);beam(v(-98,y,-80),v(-102,y+4,-80),.14,m.steel);}for(const yy of [15,24]){const dish=mesh(new T.SphereGeometry(3,20,12,0,Math.PI*2,0,.65),m.sand,-100,antennaY+yy,-84);dish.rotation.x=-Math.PI/2;beam(v(-100,antennaY+yy,-87),v(-100,antennaY+yy,-91),.09,m.dark);}warehouse(-88,-94,15,11);
  // A shallow drained canal splits the depot, with generous crossable bridge decks.
  const waterMat=new T.MeshStandardMaterial({color:0x536f69,roughness:.26,metalness:.4,transparent:true,opacity:.78});
  for(let z=-112;z<20;z+=12){const x=46+Math.sin(z*.035)*7,y=groundHeight(x,z);box(x,y+.02,z,9,.035,12,waterMat);for(const dx of [-5.3,5.3])box(x+dx,y+.12,z,.55,.24,12,m.concrete);}
  for(const z of [-88,-44,4])box(46+Math.sin(z*.035)*7,groundHeight(46,z)+.18,z,14,.25,7,m.steel);
  for(let z=-100;z<110;z+=4){const x=-139;box(x,groundHeight(x,z)+.12,z,5,.2,.4,m.bark);for(const dx of [-1.5,1.5])box(x+dx,groundHeight(x+dx,z)+.25,z,.12,.22,4,m.dark);}
  // Exposed service pipes connect the tank farm, with curved elbow caps.
  for(const z of [-39,-42]){beam(v(114,3+groundHeight(114,z),z),v(151,3+groundHeight(151,z),z),.65,m.rust);for(const x of [116,132,148])box(x,groundHeight(x,z)+1.5,z,.3,3,.8,m.dark);const elbow=mesh(new T.TorusGeometry(1,.32,7,12,Math.PI/2),m.rust,114,groundHeight(114,z)+2,z);elbow.rotation.z=Math.PI/2;}
  function truck(x:number,z:number){const y=groundHeight(x,z);box(x,y+1,z,2.8,.4,7,m.dark,true);box(x,y+1.9,z+2,2.8,2.1,2.3,m.sage);box(x,y+2.25,z+3.19,2.25,.8,.05,m.glass);box(x,y+1.15,z-1.6,2.9,.35,4.5,m.rust);for(const dx of [-1.42,1.42]){box(x+dx,y+1.8,z-1.6,.12,1.2,4.4,m.rust);for(const dz of [-2,2]){const wheel=mesh(new T.CylinderGeometry(.65,.65,.4,12),m.black,x+dx,y+.7,z+dz,true);wheel.rotation.z=Math.PI/2;const hub=mesh(new T.CylinderGeometry(.27,.27,.43,8),m.steel,x+dx,y+.7,z+dz);hub.rotation.z=Math.PI/2;}}for(const dx of [-.9,.9])box(x+dx,y+1.4,z+3.25,.4,.3,.1,m.sand);}
  truck(-48,80);truck(96,-93);truck(-117,-45);
  const lamps:T.Mesh[]=[];for(const p of [[-21,119],[-79,99],[-112,-37],[103,3],[76,-106],[-41,-143]]){const [x,z]=p,y=groundHeight(x,z);cyl(x,y+4,z,.1,8,m.dark);box(x+1,y+7.9,z,2,.15,.15,m.dark);const bulb=mesh(new T.BoxGeometry(.7,.15,.45),m.light,x+1.9,y+7.8,z);lamps.push(bulb);}
  for(const pair of [[[-21,119],[-79,99]],[[-79,99],[-112,-37]]]){const [a,b]=pair;const curve=new T.CatmullRomCurve3([v(a[0],groundHeight(...a as [number,number])+8,a[1]),v((a[0]+b[0])/2,4,(a[1]+b[1])/2),v(b[0],groundHeight(...b as [number,number])+8,b[1])]);mesh(new T.TubeGeometry(curve,16,.025,3,false),m.dark,0,0,0);}
  function loot(x:number,z:number,tier:number){const y=groundHeight(x,z),g=new T.Group();g.position.set(x,y,z);const body=new T.Mesh(new T.BoxGeometry(1.35,.75,.85),tier===3?m.dark:m.sage);body.position.y=.4;g.add(body);const lid=new T.Mesh(new T.BoxGeometry(1.45,.12,.94),m.sand);lid.position.y=.83;g.add(lid);for(const dx of [-.47,.47]){const strap=new T.Mesh(new T.BoxGeometry(.085,.8,.88),m.dark);strap.position.set(dx,.43,0);g.add(strap);}const latch=new T.Mesh(new T.BoxGeometry(.17,.2,.04),m.light);latch.position.set(0,.67,.48);g.add(latch);scene.add(g);containers.push({id:containers.length,position:g.position.clone(),mesh:g,tier,opened:false});}
  for(const p of [[-5,134],[12,125],[-23,119],[-39,102],[35,99],[-60,79],[-76,67],[-58,54],[-101,56],[20,61],[65,37],[97,10]])loot(p[0],p[1],1);
  for(const p of [[-116,-54],[-87,-85],[-77,-62],[-105,-102],[68,-45],[85,-58],[105,-82],[129,-18],[-32,-63],[18,-99]])loot(p[0],p[1],2);
  for(const p of [[-47,-137],[26,-151],[75,-143],[-80,-126],[128,-96],[148,5]])loot(p[0],p[1],3);
  for(const p of [[-31,84],[31,-29],[-13,-121]])loot(p[0],p[1],3);
  const extractions=[v(-40,groundHeight(-40,-160),-160),v(65,groundHeight(65,-165),-165)];const beacons:T.Mesh[]=[];
  for(const p of extractions){const pad=mesh(new T.CylinderGeometry(8,8,.24,8),m.dark,p.x,p.y+.12,p.z);pad.receiveShadow=true;const ring=mesh(new T.RingGeometry(6.6,6.9,48),m.light,p.x,p.y+.26,p.z);ring.rotation.x=-Math.PI/2;box(p.x,p.y+.27,p.z,5,.025,.5,m.sand);for(const dx of [-2.4,2.4])box(p.x+dx,p.y+.27,p.z,.5,.025,4,m.sand);for(const dx of [-8,8]){beam(v(p.x+dx,p.y,p.z+3),v(p.x+dx*.65,p.y+8,p.z+3),.3,m.dark);box(p.x+dx*.65,p.y+8,p.z+3,2,.2,.7,m.light);}const beacon=mesh(new T.CylinderGeometry(.11,.11,12,8),new T.MeshBasicMaterial({color:0xffcf85,transparent:true,opacity:.4}),p.x-6,p.y+6,p.z+5);beacons.push(beacon);sign('EVAC / UPLINK',p.x,p.z-9,6);}
  // Low shelter and field repairs make the deployment point a inhabited place.
  const campY=groundHeight(-10,150);for(const dx of [-4,4])for(const dz of [-3,3])box(-10+dx,campY+1.6,150+dz,.1,3.2,.1,m.bark);const tarp=mesh(new T.BoxGeometry(4.4,.05,7),m.sage,-12,campY+3.5,150);tarp.rotation.z=.2;const tarp2=mesh(new T.BoxGeometry(4.4,.05,7),m.sage,-8,campY+3.5,150);tarp2.rotation.z=-.2;box(-10,campY+.3,150,3,.45,1.4,m.dark);box(-14,campY+.7,147,1.2,1.4,1.2,m.rust);box(-6,campY+.8,148,1.5,.12,.8,m.sand);cyl(-6,campY+1.1,148,.12,.4,m.light);sign('DUSTFALL / FIELD CAMP',7,156,7);
  // Broad woodland islands preserve three legible routes rather than fencing a corridor.
  const clear=(x:number,z:number)=>onRoad(x,z,3)||Math.hypot(x,z-145)<24||Math.hypot(x+170,z-145)<20||Math.hypot(x-170,z-145)<20||zones.some(p=>Math.hypot(x-p.x,z-p.z)<32)||colliders.some(c=>Math.abs(x-c.x)<c.hx+5&&Math.abs(z-c.z)<c.hz+5)||Math.abs(x)<22||Math.abs(x-(50+Math.sin(z*.02)*32))<12||Math.abs(x-(-90+Math.sin(z*.015)*25))<15;
  for(let i=0;i<530;i++){const x=rand()*410-205,z=rand()*410-205;if(clear(x,z))continue;const y=groundHeight(x,z),h=5+rand()*6;batch('trunks',cylinder,m.bark,x,y+h*.43,z,.18+rand()*.15,h*.86,.18);for(let k=0;k<4;k++){const dx=(rand()-.5)*3,dz=(rand()-.5)*3;batch(k%2?'leaves':'leaves2',leafGeo,k%2?m.leaf:m.leaf2,x+dx,y+h*(.7+rand()*.25),z+dz,2+rand(),1.7+rand()*1.5,2+rand(),rand()*6);}}
  const grassGeo=new T.BufferGeometry();grassGeo.setAttribute('position',new T.Float32BufferAttribute([-.15,0,0,.15,0,0,.03,.7,.03,0,0,-.15,0,0,.15,.04,.55,0],3));grassGeo.computeVertexNormals();const grassMat=new T.MeshStandardMaterial({color:0x777e53,side:T.DoubleSide,roughness:1});
  for(let i=0;i<8500;i++){const x=rand()*415-207,z=rand()*415-207;if(onRoad(x,z)||clear(x,z)&&rand()>.15)continue;const h=.45+rand()*.75;batch('grass',grassGeo,grassMat,x,groundHeight(x,z)+.01,z,h,h,h,rand()*6);}
  for(let i=0;i<170;i++){const a=rand()*Math.PI*2,r=24+rand()*22,x=Math.cos(a)*r,z=Math.sin(a)*r-7,s=1+rand()*3;if(onRoad(x,z,s)||Math.abs(x)<14||Math.abs(z+7)<9)continue;batch('basin-rocks',rockGeo,m.rock,x,groundHeight(x,z)+s*.35,z,s,s*.8,s*.8,rand()*6,true);colliders.push({x,z,hx:s*.65,hz:s*.55,height:s*1.1});}
  // Continuous, inward-facing distant ridgelines replace nearby overlapping boulders.
  for(let layer=0;layer<3;layer++){
    const ridgeVerts:number[]=[],ridgeIndices:number[]=[],count=160,radius=390+layer*95;
    for(let i=0;i<=count;i++){
      const a=i/count*Math.PI*2,crest=20+layer*11+Math.sin(a*5+layer)*9+Math.sin(a*11-layer)*6+Math.sin(a*23+layer)*3;
      ridgeVerts.push(Math.cos(a)*radius,-35,Math.sin(a)*radius,Math.cos(a)*radius,crest,Math.sin(a)*radius);
      if(i<count){const k=i*2;ridgeIndices.push(k,k+2,k+1,k+1,k+2,k+3);}
    }
    const ridgeGeometry=new T.BufferGeometry();ridgeGeometry.setAttribute('position',new T.Float32BufferAttribute(ridgeVerts,3));ridgeGeometry.setIndex(ridgeIndices);
    const ridge=new T.Mesh(ridgeGeometry,new T.MeshBasicMaterial({color:[0x657d7b,0x7d9395,0x94a7aa][layer]}));scene.add(ridge);
  }
  for(const [key,b] of batches){const inst=new T.InstancedMesh(b.g,b.m,b.matrices.length);b.matrices.forEach((matrix,i)=>inst.setMatrixAt(i,matrix));inst.castShadow=key!=='grass';inst.receiveShadow=true;inst.computeBoundingSphere();scene.add(inst);if(b.solid)solids.push(inst);}
  return {solids,colliders,groundHeight,containers,zones,extractions,update(t:number,_dt:number){skyMaterial.uniforms.time.value=t;for(let i=0;i<beacons.length;i++){const material=beacons[i].material as T.MeshBasicMaterial;material.opacity=.28+Math.sin(t*2+i)*.1;}}};
}
