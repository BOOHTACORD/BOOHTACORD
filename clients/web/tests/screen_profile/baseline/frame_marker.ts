const FRAME_BITS = 12
const SIGNATURE = 0xa6
const FRAME_MASK = (1 << FRAME_BITS) - 1
const COLUMNS = 5
const ROWS = 4
const CELL_SIZE = 24
const MARKER_X = 32
const MARKER_Y = 128

export function encodeFrameMarker(frame: number) {
  const signature = Array.from({ length: 8 }, (_, bit) => Boolean(SIGNATURE & (1 << bit)))
  const value = Math.trunc(frame) & FRAME_MASK
  return [...signature, ...Array.from({ length: FRAME_BITS }, (_, bit) => Boolean(value & (1 << bit)))]
}

export function decodeFrameMarker(luma: number[]) {
  if (luma.length < COLUMNS * ROWS || luma.slice(0, 20).some(value => !Number.isFinite(value))) return null
  const bits = luma.slice(0, 20).map(value => value >= 128)
  const signature = bits.slice(0, 8).reduce((value, bit, index) => bit ? value | (1 << index) : value, 0)
  if (signature !== SIGNATURE) return null
  return bits.slice(8).reduce((value, bit, index) => bit ? value | (1 << index) : value, 0)
}

export function drawFrameMarker(context: CanvasRenderingContext2D, frame: number) {
  context.fillStyle = '#ff00ff'
  context.fillRect(MARKER_X - 4, MARKER_Y - 4, COLUMNS * CELL_SIZE + 8, ROWS * CELL_SIZE + 8)
  encodeFrameMarker(frame).forEach((bit, index) => {
    context.fillStyle = bit ? '#ffffff' : '#000000'
    context.fillRect(MARKER_X + (index % COLUMNS) * CELL_SIZE, MARKER_Y + Math.floor(index / COLUMNS) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
  })
}

type MarkerGeometry = { x:number; y:number; cell:number; width:number; height:number }
const geometries = new WeakMap<HTMLCanvasElement,MarkerGeometry>()

function readGeometry(video:HTMLVideoElement,canvas:HTMLCanvasElement,geometry:MarkerGeometry) {
 canvas.width=COLUMNS*CELL_SIZE;canvas.height=ROWS*CELL_SIZE
 const context=canvas.getContext('2d',{willReadFrequently:true})
 if(!context)return null
 context.drawImage(video,geometry.x,geometry.y,COLUMNS*geometry.cell,ROWS*geometry.cell,0,0,canvas.width,canvas.height)
 const pixels=context.getImageData(0,0,canvas.width,canvas.height).data
 const luma:number[]=[]
 for(let index=0;index<COLUMNS*ROWS;index++){
  const pixel=((Math.floor(index/COLUMNS)*CELL_SIZE+CELL_SIZE/2)*canvas.width+(index%COLUMNS)*CELL_SIZE+CELL_SIZE/2)*4
  luma.push((pixels[pixel]+pixels[pixel+1]+pixels[pixel+2])/3)
 }
 return decodeFrameMarker(luma)
}

// Numbered synthetic source only. A bounded top-left ROI locates its magenta
// border after capture scaling/translation. No private frame is retained.
export function readFrameMarker(video:HTMLVideoElement,canvas:HTMLCanvasElement) {
 if(video.videoWidth<20||video.videoHeight<20)return null
 const cached=geometries.get(canvas)
 if(cached&&cached.width===video.videoWidth&&cached.height===video.videoHeight){
  const value=readGeometry(video,canvas,cached);if(value!==null)return value
 }
 if(video.videoWidth>=MARKER_X+COLUMNS*CELL_SIZE&&video.videoHeight>=MARKER_Y+ROWS*CELL_SIZE){
  const direct={x:MARKER_X,y:MARKER_Y,cell:CELL_SIZE,width:video.videoWidth,height:video.videoHeight}
  const value=readGeometry(video,canvas,direct)
  if(value!==null){geometries.set(canvas,direct);return value}
 }
 canvas.width=Math.min(320,video.videoWidth);canvas.height=Math.min(320,video.videoHeight)
 const context=canvas.getContext('2d',{willReadFrequently:true});if(!context)return null
 context.drawImage(video,0,0,canvas.width,canvas.height,0,0,canvas.width,canvas.height)
 const pixels=context.getImageData(0,0,canvas.width,canvas.height).data
 let left=canvas.width,top=canvas.height,right=-1,bottom=-1
 for(let y=0;y<canvas.height;y++)for(let x=0;x<canvas.width;x++){
  const at=(y*canvas.width+x)*4
  if(pixels[at]>170&&pixels[at+1]<100&&pixels[at+2]>170){left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y)}
 }
 if(right<left||bottom<top)return null
 const horizontal=(right-left+1)/(COLUMNS*CELL_SIZE+8),vertical=(bottom-top+1)/(ROWS*CELL_SIZE+8)
 if(horizontal<.25||horizontal>2||Math.abs(horizontal-vertical)>.15)return null
 const scale=(horizontal+vertical)/2
 const geometry={x:left+4*scale,y:top+4*scale,cell:CELL_SIZE*scale,width:video.videoWidth,height:video.videoHeight}
 const value=readGeometry(video,canvas,geometry)
 if(value!==null)geometries.set(canvas,geometry)
 return value
}
