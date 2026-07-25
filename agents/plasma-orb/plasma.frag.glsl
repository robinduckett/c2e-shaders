// Volumetric "energy tendrils" plasma — ported from the public-domain Shadertoy
// (Star-Nest-style ray-marched energy inside a reflective sphere). The original
// iChannel0 texture lookups are replaced with procedural value noise. Scene-read:
// the emissive plasma is composited additively over the world beneath it, with a
// radial fade so it reads as a contained orb.
//
//   param(0) = brightness                             (default 1)
//   param(1) = orb diameter in sprite-PIXELS, 0 = fill the frame
#define CESHAD_SCENE
#define CESHAD_BLEED 24

// Ray/step counts. Lowered from the original (25/19/35) so a per-frame agent
// shader stays real-time; raise for more tendril density if your GPU allows.
#define NUM_RAYS 14
#define VOLUMETRIC_STEPS 16
#define MAX_ITER 32
#define FAR 6.0

mat2 mm2(float a){ float c=cos(a), s=sin(a); return mat2(c,-s,s,c); }
float hash1(float n){ return fract(sin(n)*43758.5453); }

// procedural replacements for the original iChannel0 texture noise
float n1(float x){                 // was textureLod(iChannel0,(x*.01,1)).x
    x *= 0.01;
    float i=floor(x), f=fract(x); f=f*f*(3.0-2.0*f);
    return mix(hash1(i), hash1(i+1.0), f);
}
float n3(vec3 p){                  // was 3D value noise from iChannel0
    vec3 ip=floor(p), fp=fract(p); fp=fp*fp*(3.0-2.0*fp);
    float n = ip.x + ip.y*57.0 + ip.z*113.0;
    return mix(mix(mix(hash1(n),       hash1(n+1.0),   fp.x),
                   mix(hash1(n+57.0),  hash1(n+58.0),  fp.x), fp.y),
               mix(mix(hash1(n+113.0), hash1(n+114.0), fp.x),
                   mix(hash1(n+170.0), hash1(n+171.0), fp.x), fp.y), fp.z);
}

const mat3 m3mat = mat3( 0.00, 0.80, 0.60,
                        -0.80, 0.36,-0.48,
                        -0.60,-0.48, 0.64 );

float flow(vec3 p, float t, float time){
    float z=2.0, rz=0.0; vec3 bp=p;
    for (float i=1.0;i<5.0;i++){
        p += time*0.1;
        rz += (sin(n3(p+t*0.8)*6.0)*0.5+0.5)/z;
        p = mix(bp,p,0.6);
        z *= 2.0; p *= 2.01; p = p * m3mat;
    }
    return rz;
}
float sins(float x, float time){
    float rz=0.0, z=2.0;
    for (float i=0.0;i<3.0;i++){
        rz += abs(fract(x*1.4)-0.5)/z;
        x *= 1.3; z *= 1.15; x -= time*0.65*z;
    }
    return rz;
}
float segm(vec3 p, vec3 a, vec3 b){
    vec3 pa=p-a, ba=b-a;
    float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
    return length(pa-ba*h)*0.5;
}
vec3 pathf(float i, float d, float time){
    vec3 en=vec3(0.0,0.0,1.0);
    float sns2=sins(d+i*0.5,time)*0.22;
    float sns =sins(d+i*0.6,time)*0.21;
    en.xz = en.xz * mm2((hash1(i*10.569)-0.5)*6.2+sns2);
    en.xy = en.xy * mm2((hash1(i*4.732)-0.5)*6.2+sns);
    return en;
}
vec2 mapf(vec3 p, float i, float time){
    float lp=length(p);
    vec3 en=pathf(i,lp,time);
    float ins=smoothstep(0.11,0.46,lp);
    float outs=0.15+smoothstep(0.0,0.15,abs(lp-1.0));
    p *= ins*outs;
    float id=ins*outs;
    float rz=segm(p,vec3(0.0),en)-0.011;
    return vec2(rz,id);
}
float march(vec3 ro, vec3 rd, float startf, float maxd, float j, float time){
    float precis=0.001, h=0.5, d=startf;
    for(int i=0;i<MAX_ITER;i++){
        if(abs(h)<precis||d>maxd) break;
        d += h*1.2;
        h = mapf(ro+rd*d,j,time).x;
    }
    return d;
}
vec3 vmarch(vec3 ro, vec3 rd, float j, vec3 orig, float time){
    vec3 p=ro; vec2 r=vec2(0.0); vec3 sum=vec3(0.0);
    for(int i=0;i<VOLUMETRIC_STEPS;i++){
        r=mapf(p,j,time);
        p += rd*0.03;
        float lp=length(p);
        vec3 col=sin(vec3(1.05,2.5,1.52)*3.94+r.y)*0.85+0.4;
        col *= smoothstep(0.0,0.015,-r.x);
        col *= smoothstep(0.04,0.2,abs(lp-1.1));
        col *= smoothstep(0.1,0.34,lp);
        sum += abs(col)*5.0*(1.2-n1(lp*2.0+j*13.0+time*5.0)*1.1)/(log(distance(p,orig)-2.0)+0.75);
    }
    return sum;
}
vec2 iSphere2(vec3 ro, vec3 rd){
    vec3 oc=ro;
    float b=dot(oc,rd);
    float c=dot(oc,oc)-1.0;
    float h=b*b-c;
    if(h<0.0) return vec2(-1.0);
    return vec2(-b-sqrt(h), -b+sqrt(h));
}

// `texel` is never read: the orb is procedural and its containment comes from the
// radial mask on the frame uv, not from the sprite's alpha.
vec4 shade(vec4 texel, vec2 uv)
{
    vec2 screenUV = sceneUV();

    float intensity = (param(0) > 0.0) ? param(0) : 1.0;   // param0: brightness
    // param1: orb diameter in PIXELS. Expressed in pixels rather than sprite-UV
    // so the same value gives the same on-screen orb whatever frame the agent is
    // on — an agent that swaps to a smaller frame needs no restatement, which is
    // what lets the swap happen without a visible jump.
    // 0 (default / param absent) means "fill the frame", i.e. s = 1.0.
    float sizePx   = (param(1) > 0.0) ? param(1) : 0.0;
    vec2  perPixel = texelSize() / (v_spriteRect.zw - v_spriteRect.xy);
    float s        = (sizePx > 0.0) ? (sizePx * perPixel.x) : 1.0;
    vec2  uvS      = (uv - 0.5) / s + 0.5;         // sprite uv scaled about the frame centre
    float time = shaderTime() * 1.1;

    vec2 p  = uvS - 0.5;             // square sprite (aspect 1:1)
    vec2 um = vec2(0.0);             // no mouse

    vec3 ro = vec3(0.0, 0.0, 5.0);
    vec3 rd = normalize(vec3(p * 0.7, -1.5));
    mat2 mx = mm2(time*0.4 + um.x*6.0);
    mat2 my = mm2(time*0.3 + um.y*6.0);
    ro.xz = ro.xz * mx; rd.xz = rd.xz * mx;
    ro.xy = ro.xy * my; rd.xy = rd.xy * my;

    vec3 bro = ro, brd = rd;
    vec3 col = vec3(0.0125, 0.0, 0.025);
    for (float j=1.0; j<float(NUM_RAYS)+1.0; j++){
        ro = bro; rd = brd;
        mat2 mm = mm2((time*0.1 + ((j+1.0)*5.1))*j*0.25);
        ro.xy = ro.xy * mm; rd.xy = rd.xy * mm;
        ro.xz = ro.xz * mm; rd.xz = rd.xz * mm;
        float rz = march(ro,rd,2.5,FAR,j,time);
        if (rz >= FAR) continue;
        vec3 pos = ro + rz*rd;
        col = max(col, vmarch(pos,rd,j,bro,time));
    }

    ro = bro; rd = brd;
    vec2 sph = iSphere2(ro,rd);
    if (sph.x > 0.0){
        vec3 pos  = ro + rd*sph.x;
        vec3 pos2 = ro + rd*sph.y;
        vec3 rf  = reflect(rd,pos);
        vec3 rf2 = reflect(rd,pos2);
        float nz  = (-log(abs(flow(rf *1.2, time, time)-0.01)));
        float nz2 = (-log(abs(flow(rf2*1.2,-time, time)-0.01)));
        col += (0.1*nz*nz*vec3(0.12,0.12,0.5) + 0.05*nz2*nz2*vec3(0.55,0.2,0.55))*0.8;
    }
    col *= 1.3;

    // Composite the emissive plasma over the scene: subtract the ambient base so
    // empty pixels are transparent, radial-fade at the sprite edge, add over the
    // world beneath.
    col -= vec3(0.0125, 0.0, 0.025) * 1.3;
    col = max(col, 0.0);
    float  rad   = length(uvS - 0.5) * 2.0;
    float  mask  = 1.0 - smoothstep(0.72, 1.0, rad);
    vec3 sceneHere = sceneBehind(screenUV).rgb;
    vec3 outc = sceneHere + col * intensity * mask;
    return vec4(outc, 1.0);
}
