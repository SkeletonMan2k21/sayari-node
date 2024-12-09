import { default as express, Express, Request, Response, NextFunction } from 'express';
import 'dotenv/config';
import { Authenticator } from './lib/authenticator.ts';

const app = express();
const port = process.env.PORT;


app.get('/authenticate', (req: Request, res: Response) => {
    const authenticator = new Authenticator(req);
    authenticator.authenticate();
    res.send('Auth')
})


app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
    console.error(err.stack);
    res.set({
      'Content-Type': 'application/json',
    });

    res.status(500).send(JSON.stringify({'status':'error','message':err}, null, 4));
});

app.use((req: Request, res: Response, next: NextFunction) => {
    res.set({
      'Content-Type': 'application/json',
    });
    const path = req.baseUrl + req.path;
    res.status(404).send(JSON.stringify({'error':'error','message':`${path} was not found.`}, null, 4));
})

app.listen(port, () => {
  console.log(`server running on port ${port}`);
});
